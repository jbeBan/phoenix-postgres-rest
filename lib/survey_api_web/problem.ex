defmodule SurveyApiWeb.Problem do
  @moduledoc "RFC 9457 problem details: the shape of every error response."

  import Plug.Conn

  @doc "The problem document as a map."
  def body(status, title \\ nil, extra \\ %{}) do
    Map.merge(
      %{type: "about:blank", title: title || reason_phrase(status), status: status},
      Map.new(extra)
    )
  end

  @doc "Sends the problem as `application/problem+json`."
  def respond(conn, status, title \\ nil, extra \\ %{}) do
    conn
    |> put_resp_content_type("application/problem+json")
    |> send_resp(status, Jason.encode_to_iodata!(body(status, title, extra)))
  end

  def reason_phrase(status), do: Plug.Conn.Status.reason_phrase(status)
end
