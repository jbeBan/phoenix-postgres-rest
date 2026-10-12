defmodule SurveyApi.Repo do
  use Ecto.Repo,
    otp_app: :survey_api,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Runs whenever the repo starts: the application, `bin/migrate`, `mix ecto.*` and `mix survey_api.explain`.

  There is deliberately no default database, so a missing URL stops the process with a clear message instead
  of retrying a connection to some localhost default.
  """
  @impl true
  def init(_context, config) do
    {:ok, ensure_url!(config)}
  end

  def ensure_url!(config) do
    if config[:url] in [nil, ""] do
      raise "DATABASE_URL is not set (e.g. postgresql://user:password@host:5432/dbname)"
    end

    config
  end
end
