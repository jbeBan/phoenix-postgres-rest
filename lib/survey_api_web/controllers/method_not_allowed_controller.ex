defmodule SurveyApiWeb.MethodNotAllowedController do
  @moduledoc "Phoenix answers a known path with the wrong verb as 404; the router sends those here for a 405."

  use SurveyApiWeb, :controller

  alias SurveyApiWeb.Problem

  def not_allowed(conn, _params) do
    conn
    |> put_resp_header("allow", conn.private.allow)
    |> Problem.send(405, nil, detail: "The method is not allowed for the requested URL.")
  end
end
