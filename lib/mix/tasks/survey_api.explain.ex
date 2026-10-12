defmodule Mix.Tasks.SurveyApi.Explain do
  @shortdoc "EXPLAINs the survey_id filter with no index, a single-column index and the shipped composite index"

  @moduledoc """
  Seeds ~500k rows, then runs EXPLAIN ANALYZE on the survey_id filter in three states: no index, a
  single-column index, and the composite index the app ships with.

  This task wipes the database's public schema and re-runs the migrations, so it refuses to run unless the
  target database name ends in `_explain`.

      EXPLAIN_DATABASE_URL=postgresql://postgres@localhost:5433/survey_api_explain mix survey_api.explain

  `EXPLAIN_DATABASE_URL` defaults to `survey_api_explain` on the local dev cluster (port 5433).
  """

  use Mix.Task

  alias SurveyApi.Repo

  @default_url "postgresql://postgres@localhost:5433/survey_api_explain"
  @rows 500_000
  # ~100 rows per survey, so the filter is highly selective
  @surveys 5_000
  # Same shape as the statement Ecto emits for GET /v1/responses?survey_id=42 (limit + 1 rows)
  @query "SELECT * FROM responses WHERE survey_id = 42 ORDER BY id LIMIT 51"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    url = System.get_env("EXPLAIN_DATABASE_URL", @default_url)
    database = url |> URI.parse() |> Map.fetch!(:path) |> String.trim_leading("/")

    unless String.ends_with?(database, "_explain") do
      Mix.raise(
        "refusing to run: database #{inspect(database)} does not end in '_explain' (this task wipes the schema)"
      )
    end

    {:ok, repo} =
      Repo.start_link(
        name: nil,
        url: url,
        pool: DBConnection.ConnectionPool,
        pool_size: 2,
        log: false
      )

    Repo.put_dynamic_repo(repo)

    Repo.query!("DROP SCHEMA public CASCADE")
    Repo.query!("CREATE SCHEMA public")
    Ecto.Migrator.run(Repo, :up, all: true, dynamic_repo: repo, log: false)

    # Measure without the shipped index first.
    Repo.query!("DROP INDEX idx_responses_survey_id_id")

    Repo.query!(
      "INSERT INTO surveys (title) SELECT 'Survey ' || g FROM generate_series(1, $1) AS g",
      [@surveys]
    )

    Repo.query!(
      """
      INSERT INTO responses (survey_id, respondent, rating, comment)
      SELECT 1 + (random() * $1)::int, 'user' || g || '@example.com', 1 + (random() * 4)::int, md5(g::text)
      FROM generate_series(1, $2) AS g
      """,
      [@surveys - 1, @rows]
    )

    Repo.query!("ANALYZE responses")
    explain("BEFORE: no index on survey_id")

    Repo.query!("CREATE INDEX idx_single ON responses (survey_id)")
    Repo.query!("ANALYZE responses")
    explain("AFTER 1: single-column index (survey_id)")

    Repo.query!("DROP INDEX idx_single")
    Repo.query!("CREATE INDEX idx_responses_survey_id_id ON responses (survey_id, id)")
    Repo.query!("ANALYZE responses")
    explain("AFTER 2: composite index (survey_id, id)  <- shipped in the migration")
  end

  defp explain(label) do
    Mix.shell().info("\n=== #{label} ===")
    %{rows: rows} = Repo.query!("EXPLAIN (ANALYZE, BUFFERS) " <> @query)
    Enum.each(rows, fn [line] -> Mix.shell().info(line) end)
  end
end
