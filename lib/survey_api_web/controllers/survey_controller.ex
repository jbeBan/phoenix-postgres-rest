defmodule SurveyApiWeb.SurveyController do
  use SurveyApiWeb, :controller

  alias SurveyApi.Limits
  alias SurveyApi.Surveys
  alias SurveyApiWeb.QueryParams

  action_fallback SurveyApiWeb.FallbackController

  plug SurveyApiWeb.Plugs.JsonBody when action == :create

  def create(conn, _params) do
    with {:ok, attrs} <- Surveys.validate_new(conn.assigns.json_body),
         {:ok, survey} <- Surveys.create(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/v1/surveys/#{survey.id}")
      |> render(:show, survey: survey)
    end
  end

  def index(conn, params) do
    with {:ok, %{limit: limit, offset: offset}} <- QueryParams.paging(params) do
      render(conn, :index, rows: Surveys.list(limit, offset), limit: limit, offset: offset)
    end
  end

  # ids beyond the column's range can't exist, so they are a 404 rather than a Postgres error.
  def show(conn, %{"id" => raw_id}) do
    with {:ok, id} <- QueryParams.path_id(raw_id, Limits.int32_max()),
         %{} = survey <- Surveys.get(id) do
      render(conn, :show, survey: survey)
    else
      _ -> QueryParams.not_found("survey", raw_id)
    end
  end
end
