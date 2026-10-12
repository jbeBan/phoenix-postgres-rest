defmodule SurveyApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    ensure_database_configured!(Application.get_env(:survey_api, SurveyApi.Repo, []))

    children = [
      SurveyApi.Repo,
      {Phoenix.PubSub, name: SurveyApi.PubSub},
      SurveyApiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SurveyApi.Supervisor)
  end

  @doc """
  Fails at startup (the container stops) rather than serving 503s from a dead default: there is deliberately
  no default database, so a missing URL must be an error.
  """
  def ensure_database_configured!(repo_config) do
    if repo_config[:url] in [nil, ""] do
      raise "DATABASE_URL is not set (e.g. postgresql://user:password@host:5432/dbname)"
    end

    :ok
  end
end
