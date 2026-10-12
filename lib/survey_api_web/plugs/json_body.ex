defmodule SurveyApiWeb.Plugs.JsonBody do
  @moduledoc """
  Reads a JSON request body into `conn.assigns.json_body`.

    * 415 unless `Content-Type` is `application/json` (or `application/*+json`)
    * 413 if the body is larger than 64 KiB
    * a malformed body is assigned as `nil`, so validation reports it like any other non-object (400)
  """

  import Plug.Conn

  alias SurveyApiWeb.Problem

  @behaviour Plug

  @max_bytes 64 * 1024

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    cond do
      not json?(conn) ->
        reject(conn, 415, detail: "Content-Type must be application/json")

      too_large?(conn) ->
        reject(conn, 413, detail: "The request body is larger than #{@max_bytes} bytes.")

      true ->
        case read_body(conn, length: @max_bytes) do
          {:ok, body, conn} ->
            assign(conn, :json_body, decode(body))

          {:more, _partial, conn} ->
            reject(conn, 413, detail: "The request body is larger than #{@max_bytes} bytes.")

          {:error, _reason} ->
            reject(conn, 400, detail: "The request body could not be read.")
        end
    end
  end

  defp reject(conn, status, extra), do: conn |> Problem.send(status, nil, extra) |> halt()

  defp json?(conn) do
    with [value | _] <- get_req_header(conn, "content-type"),
         {:ok, type, subtype, _params} <- Plug.Conn.Utils.media_type(value) do
      type == "application" and (subtype == "json" or String.ends_with?(subtype, "+json"))
    else
      _ -> false
    end
  end

  defp too_large?(conn) do
    case get_req_header(conn, "content-length") do
      [value | _] -> match?({n, ""} when n > @max_bytes, Integer.parse(value))
      [] -> false
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> nil
    end
  end
end
