defmodule SurveyApiWeb.HealthController do
  use SurveyApiWeb, :controller

  alias SurveyApiWeb.Problem

  @doc "The process is up (no dependencies checked)."
  def liveness(conn, _params), do: json(conn, %{status: "ok"})

  @doc "The process can serve traffic: the database answers."
  def readiness(conn, _params) do
    case SurveyApi.Repo.query("SELECT 1", [], timeout: 3_000) do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, _} -> Problem.send(conn, 503, nil, detail: "database unavailable")
    end
  end
end
