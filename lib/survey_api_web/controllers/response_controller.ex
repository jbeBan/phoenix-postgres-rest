defmodule SurveyApiWeb.ResponseController do
  use SurveyApiWeb, :controller

  alias SurveyApi.Limits
  alias SurveyApi.Responses
  alias SurveyApiWeb.QueryParams

  action_fallback SurveyApiWeb.FallbackController

  plug SurveyApiWeb.Plugs.JsonBody when action == :create

  def create(conn, _params) do
    with {:ok, attrs} <- validate(Responses.validate_new(conn.assigns.json_body)),
         {:ok, response} <- Responses.create(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/v1/responses/#{response.id}")
      |> render(:show, response: response)
    end
  end

  def index(conn, params) do
    with {:ok, %{limit: limit, offset: offset, survey_id: survey_id}} <-
           QueryParams.paging(params, [{"survey_id", 1, Limits.int32_max()}]) do
      render(conn, :index,
        rows: Responses.list(survey_id, limit, offset),
        limit: limit,
        offset: offset
      )
    end
  end

  def show(conn, %{"id" => raw_id}) do
    with {:ok, id} <- QueryParams.path_id(raw_id, Limits.int64_max()),
         %{} = response <- Responses.get(id) do
      render(conn, :show, response: response)
    else
      _ -> {:error, {:not_found, "response #{String.slice(raw_id, 0, 40)} not found"}}
    end
  end

  defp validate({:ok, attrs}), do: {:ok, attrs}
  defp validate({:error, errors}), do: {:error, {:validation, errors}}
end
