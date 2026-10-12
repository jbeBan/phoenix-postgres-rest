defmodule SurveyApiWeb.ErrorsAndHealthTest do
  use SurveyApiWeb.ConnCase

  alias SurveyApi.Repo

  test "405 is problem+json and keeps the Allow header", %{conn: conn} do
    resp = request(conn, :delete, "/v1/responses/1")
    problem(resp, 405)
    assert Plug.Conn.get_resp_header(resp, "allow") == ["GET, HEAD"]

    assert Plug.Conn.get_resp_header(request(conn, :put, "/v1/surveys"), "allow") == [
             "GET, HEAD, POST"
           ]

    assert request(conn, :patch, "/healthz") |> problem(405)
  end

  test "an unknown route is a problem+json 404", %{conn: conn} do
    assert %{"status" => 404, "title" => "Not Found"} = conn |> get("/nope") |> problem(404)
    assert conn |> get("/v1/surveys/1/extra") |> problem(404)
  end

  test "HEAD is served like GET, without a body", %{conn: conn} do
    resp = conn |> Phoenix.ConnTest.dispatch(@endpoint, :head, "/healthz")
    assert resp.status == 200
    assert resp.resp_body == ""
  end

  test "an invalid query string is a problem+json 400", %{conn: conn} do
    {400, headers, response_body} =
      assert_error_sent(400, fn -> get(conn, "/v1/surveys?limit=%FF") end)

    assert {"content-type", "application/problem+json; charset=utf-8"} in headers
    assert %{"status" => 400, "title" => "Bad Request"} = Jason.decode!(response_body)
  end

  @tag capture_log: true
  test "an unexpected exception is a problem+json 500 without details", %{conn: conn} do
    # A dynamic repo that was never started makes Ecto raise ArgumentError, a stand-in for any bug.
    Repo.put_dynamic_repo(:never_started)

    {500, headers, response_body} = assert_error_sent(500, fn -> get(conn, "/v1/surveys") end)

    assert {"content-type", "application/problem+json; charset=utf-8"} in headers

    assert Jason.decode!(response_body) == %{
             "type" => "about:blank",
             "title" => "Internal Server Error",
             "status" => 500
           }
  end

  test "liveness and readiness", %{conn: conn} do
    assert conn |> get("/healthz") |> body() == %{"status" => "ok"}
    assert conn |> get("/readyz") |> body() == %{"status" => "ok"}
  end

  describe "when the database is down" do
    @moduletag capture_log: true

    setup do
      config = Repo.config()
      {:ok, config: config}
    end

    # The application's own url wins over separate host/port/database options, so replace the url.
    for {name, change} <- [
          {"server unreachable", {:port, 1}},
          {"database missing", {:database, "does_not_exist"}}
        ] do
      test "#{name}: /readyz is 503, /healthz is still 200, data routes are 503", %{
        conn: conn,
        config: config
      } do
        {key, value} = unquote(Macro.escape(change))
        c = Keyword.put(config, key, value)

        opts =
          Keyword.merge(config,
            url: "postgresql://#{c[:username]}@#{c[:hostname]}:#{c[:port]}/#{c[:database]}",
            name: :dead_repo,
            pool: DBConnection.ConnectionPool,
            pool_size: 1,
            queue_target: 50,
            queue_interval: 100,
            connect_timeout: 500
          )

        start_supervised!({Repo, opts})
        Repo.put_dynamic_repo(:dead_repo)

        assert %{"detail" => "database unavailable"} = conn |> get("/readyz") |> problem(503)
        assert conn |> get("/healthz") |> Map.get(:status) == 200

        {503, headers, response_body} = assert_error_sent(503, fn -> get(conn, "/v1/surveys") end)
        assert {"content-type", "application/problem+json; charset=utf-8"} in headers
        assert %{"status" => 503} = Jason.decode!(response_body)
      end
    end
  end
end
