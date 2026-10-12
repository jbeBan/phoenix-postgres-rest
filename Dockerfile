# syntax=docker/dockerfile:1

# ---- build: compile the locked dependencies and the app into a self-contained release ----
FROM elixir:1.20.4-otp-29-slim AS build
ENV MIX_ENV=prod
WORKDIR /src
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN mix local.hex --force && mix local.rebar --force
# Dependencies first (cached until mix.exs / mix.lock / compile-time config change).
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile
COPY lib lib
COPY priv priv
COPY rel rel
RUN mix compile
COPY config/runtime.exs config/
RUN mix release

# ---- runtime: the release only (it bundles the Erlang runtime); no Elixir, no compilers, no root ----
FROM debian:trixie-slim
ENV LANG=C.UTF-8 \
    PORT=4000
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --no-create-home app
WORKDIR /app
COPY --from=build --chown=app:app /src/_build/prod/rel/survey_api ./
USER app
EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD ["curl", "-fsS", "http://127.0.0.1:4000/healthz"]
# DATABASE_URL and SECRET_KEY_BASE are required: the release exits at startup without them. Migrations are
# not run on start: run `bin/migrate` first (see the migrate service in compose.yaml), so several replicas
# never race to migrate.
CMD ["bin/server"]
