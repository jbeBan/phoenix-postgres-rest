defmodule SurveyApiWeb.ConnCase do
  @moduledoc """
  Test case for requests against the endpoint. Every test runs in an SQL sandbox transaction that is rolled
  back afterwards (so identity sequences are not reset: tests read ids from the responses they get).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint SurveyApiWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import SurveyApiWeb.ConnCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SurveyApi.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Sends `body` (a map, encoded as JSON, or a raw string) with the given content type."
  def request(conn, method, path, body \\ "", content_type \\ "application/json") do
    body = if is_map(body) or is_list(body), do: Jason.encode!(body), else: body

    conn
    |> Plug.Conn.put_req_header("content-type", content_type)
    |> Phoenix.ConnTest.dispatch(SurveyApiWeb.Endpoint, method, path, body)
  end

  def post_json(conn, path, body), do: request(conn, :post, path, body)

  @doc "The decoded JSON body of the response."
  def body(conn), do: Jason.decode!(conn.resp_body)

  @doc "Asserts the status and the `application/problem+json` content type; returns the decoded problem."
  def problem(conn, status) do
    ExUnit.Assertions.assert(
      conn.status == status,
      "expected #{status}, got #{conn.status}: #{conn.resp_body}"
    )

    ExUnit.Assertions.assert(single_header(conn, "content-type") =~ "application/problem+json")
    body(conn)
  end

  defp single_header(conn, name) do
    case Plug.Conn.get_resp_header(conn, name) do
      [value] -> value
      other -> ExUnit.Assertions.flunk("expected one #{name} header, got #{inspect(other)}")
    end
  end
end
