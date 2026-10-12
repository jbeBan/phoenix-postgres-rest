defmodule SurveyApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SurveyApi.Repo,
      {Phoenix.PubSub, name: SurveyApi.PubSub},
      SurveyApiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SurveyApi.Supervisor)
  end
end
