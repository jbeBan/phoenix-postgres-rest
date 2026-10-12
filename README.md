# phoenix-postgres-rest

Small REST service: Elixir + Phoenix 1.8 (API only) on PostgreSQL, Ecto 3 (Postgrex driver, built-in connection
pool), hand-rolled strict request validation, Ecto migrations. The same service as
[flask-postgres-rest](https://github.com/jbeBan/flask-postgres-rest), with the same endpoints, the same
validation rules and the same error format. Two resources: `/v1/surveys` and `/v1/responses` (answers to a survey,
with a foreign key to it).

| Method | Path | Success | Errors |
| --- | --- | --- | --- |
| POST | `/v1/surveys` | 201 + `Location` | 400 (validation), 413, 415 (not JSON) |
| GET | `/v1/surveys?limit=&offset=` | 200 `{items, limit, offset, next_offset}` | 400 |
| GET | `/v1/surveys/:id` | 200 | 404 |
| POST | `/v1/responses` | 201 + `Location` | 400 (validation, bad JSON), 413, 415, 422 (unknown `survey_id`) |
| GET | `/v1/responses?survey_id=&limit=&offset=` | 200 `{items, limit, offset, next_offset}` | 400 |
| GET | `/v1/responses/:id` | 200 | 404 |
| GET | `/healthz`, `/readyz` | 200 (readyz also checks the database) | 503 |

Fields (see [lib/survey_api/responses.ex](lib/survey_api/responses.ex)): survey `title` (1-200 chars, trimmed);
response `survey_id` (int, must exist), `respondent` (1-200 chars, trimmed), `rating` (int 1-5), `comment`
(optional, <= 2000). Validation is strict, with no type coercion (`"5"`, `5.0` and `true` are not ratings), unknown
fields are rejected, and integers are bounded to the column types, so out-of-range ids are a 404/400 rather than a
database error. Lengths are counted in code points, like Postgres' `char_length`, and NUL characters are rejected
(Postgres `text` cannot hold them). Query parameters must be plain ASCII integers (`1_0`, `+5`, ` 5 ` are
rejected). Request bodies are capped at 64 KiB.

Every error is `application/problem+json` (RFC 9457), including Phoenix's own 404 for unknown routes, a 405 for a
known path with the wrong verb (with an `Allow` header) and a 400 for an undecodable query string. Unexpected
exceptions are logged and returned as a generic 500; an exhausted pool or an unreachable database is 503.

## Layout

| Path | Role |
| --- | --- |
| `lib/survey_api/` | the domain: `Surveys` and `Responses` contexts (Ecto schemas, queries), `Validation`, `Repo` |
| `lib/survey_api_web/router.ex` | routes, including the 405 catch-alls |
| `lib/survey_api_web/controllers/` | one controller and JSON view per resource, health, the fallback that maps `{:error, _}` to problem+json |
| `lib/survey_api_web/plugs/json_body.ex` | reads the request body: 415 / 413 / malformed JSON |
| `lib/survey_api_web/{problem,query_params,page}.ex` | problem+json responses, integer parameter parsing, the pagination envelope |
| `config/` | `runtime.exs` reads the environment (see below); `config.exs` wires problem+json into Phoenix's error rendering |
| `priv/repo/migrations/` | the schema, as hand-written SQL |
| `lib/mix/tasks/survey_api.explain.ex` | the index experiment |
| `test/` | ExUnit suite (`test/support/conn_case.ex` holds the helpers) |
| `Dockerfile`, `compose.yaml`, `docker/initdb/`, `.github/workflows/ci.yml` | container image, local stack, CI |

## Run it

Requires Elixir 1.17+ (developed on 1.20 / OTP 29, e.g. via `mise use elixir erlang`) and PostgreSQL.

```bash
export LC_ALL=en_US.UTF-8 PATH=/opt/homebrew/opt/postgresql@16/bin:$PATH
initdb -D .pgdata -U postgres --auth=trust
pg_ctl -D .pgdata -o "-p 5433 -k /tmp" -l .pgdata/server.log start
createdb -h localhost -p 5433 -U postgres survey_api_dev

mix deps.get
export DATABASE_URL=postgresql://postgres@localhost:5433/survey_api_dev   # required: there is no default
mix ecto.migrate
mix phx.server                                                            # http://localhost:4000
```

Checks (CI runs the same):

```bash
mix compile --warnings-as-errors && mix format --check-formatted
mix test        # creates and migrates survey_api_test first (TEST_DATABASE_URL overrides the default)
MIX_ENV=prod mix release    # or: docker build .
```

Environment variables: `DATABASE_URL` (required in dev and prod; the app refuses to start without it, whereas
`mix test` uses `TEST_DATABASE_URL`, default `postgresql://postgres@localhost:5433/survey_api_test`),
`DB_POOL_SIZE` (10), `DB_QUEUE_TARGET` (500 ms), `PORT` (4000), and in production `SECRET_KEY_BASE` (required;
`mix phx.gen.secret`) and `PHX_HOST`. Ecto's pool has no overflow, so `DB_POOL_SIZE` is the hard cap of connections
per node; keep `nodes x DB_POOL_SIZE` below Postgres `max_connections`.

Schema change: `mix ecto.gen.migration describe_it`, write the SQL, `mix ecto.migrate`. There is no equivalent of
`alembic check`: `test/survey_api/schema_test.exs` asserts the constraints and index the code relies on instead.

## Docker

```bash
docker compose up --build      # db + one-shot migration + API on http://localhost:4000
docker compose down -v         # stop and delete the database volume
```

[compose.yaml](compose.yaml) starts Postgres 16, runs `bin/migrate` once (`migrate`), then starts the API (`api`)
after the migration succeeds. The [Dockerfile](Dockerfile) builds a `mix release` in the `elixir` image and copies
it into `debian:trixie-slim` (~270 MB, no Elixir or compilers, non-root, `/healthz` healthcheck). The release needs
`DATABASE_URL` and `SECRET_KEY_BASE` and does **not** migrate on start; run `bin/migrate` (the `migrate` service)
first, so several replicas never race to migrate.

The db port is published on `127.0.0.1:5435` (`DB_PORT` overrides) and `docker/initdb/` creates the
`survey_api_test` and `survey_api_explain` databases, so the host tools work against it too:

```bash
TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5435/survey_api_test mix test
EXPLAIN_DATABASE_URL=postgresql://postgres:postgres@localhost:5435/survey_api_explain mix survey_api.explain
```

The compose credentials (`postgres` / `postgres`) are for local use only.

## EXPLAIN: `WHERE survey_id = 42 ORDER BY id LIMIT 51` on 500k rows

`mix survey_api.explain` seeds 500k rows (refuses databases not ending in `_explain`) and prints the plans. The
plans are Postgres', not the framework's, so they match the Flask version:

| | Plan | Buffers | Execution |
| --- | --- | --- | --- |
| Before (no index) | Parallel Index Scan on `responses_pkey`, filtering `survey_id = 42` (removed ~490k rows) | 9,090 | 18.6 ms |
| Index on `(survey_id)` | Bitmap Index Scan, then a Sort of ~100 rows | 111 | 0.12 ms |
| Index on `(survey_id, id)` (shipped) | Index Scan, rows already in `id` order, stops after 51 | 54 | 0.06 ms |

Ecto emits the same statement shape (`SELECT <columns> FROM responses WHERE survey_id = $1 ORDER BY id LIMIT $2
OFFSET $3`), so the plans apply to the API. Timings vary run to run; the shape does not. The "before" plan was not a
seq scan: because of `ORDER BY id LIMIT`, the planner walks the primary key in order hoping to hit matches early,
which is still a full scan when the filter is selective. The composite index also removes the Sort and doubles as
the index for the `responses.survey_id` foreign key.

## Deliberate omissions

- The local cluster uses trust auth as `postgres`; a real deployment would use a least-privilege role.
- Offset pagination: fine here, but keyset pagination on `id` scales better for deep pages.
- No update or delete endpoints, no authentication, no rate limiting.
- `OPTIONS` is a 405 (Flask answers it automatically); there is no CORS handling.
- The image is built for local use and CI: no registry publishing, image scanning or pinned base-image digests.
  The CI workflow has not run on GitHub yet; its commands were run locally, and the Docker build and compose stack
  were run locally too.

## Compared with Flask

- Phoenix is more opinionated than Flask: routing, the endpoint plug pipeline, error rendering and the Ecto
  integration are built in, but I still removed `Plug.Parsers` and wrote a small body-reading plug, because it
  would have turned a non-object JSON body into `%{"_json" => ...}` and merged body fields into `params`, which
  makes "this body is not an object" and "strict, no unknown fields" awkward to express.
- Ecto changesets coerce (`"5"` casts to `5`), so strictness lives in `SurveyApi.Validation`, run on the raw
  decoded JSON before any changeset exists. Elixir's `true` is not an integer, so the Python `bool`-is-`int`
  surprise does not exist here.
- Error rendering is configured, not coded: a custom MIME type (`problem+json`) is registered and set as the
  endpoint's `render_errors` format, so Phoenix's own errors come out as problem+json too.
- Phoenix answers a known path with the wrong verb as 404; the router has explicit catch-all routes for the 405s.
- One BEAM node serves requests on lightweight processes behind one Ecto pool; there are no gunicorn workers to
  size against it.
