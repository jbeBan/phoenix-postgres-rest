defmodule SurveyApiWeb.FallbackController do
  @moduledoc "Turns the `{:error, _}` results of the controllers' `with` chains into problem+json responses."

  use SurveyApiWeb, :controller

  alias SurveyApiWeb.Problem

  def call(conn, {:error, {:validation, errors}}),
    do: Problem.send(conn, 400, "Validation failed", errors: errors)

  def call(conn, {:error, {:query, errors}}),
    do: Problem.send(conn, 400, "Invalid query parameters", errors: errors)

  def call(conn, {:error, {:unprocessable, errors}}),
    do: Problem.send(conn, 422, "Unprocessable Content", errors: errors)

  def call(conn, {:error, {:not_found, detail}}),
    do: Problem.send(conn, 404, "Not Found", detail: detail)
end
