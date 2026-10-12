defmodule SurveyApiWeb.SurveysTest do
  use SurveyApiWeb.ConnCase, async: true

  @url "/v1/surveys"

  test "create, get and list", %{conn: conn} do
    created = post_json(conn, @url, %{title: "  Q4 pulse  "})
    assert created.status == 201
    survey = body(created)
    assert %{"id" => id, "title" => "Q4 pulse", "created_at" => _} = survey
    assert Plug.Conn.get_resp_header(created, "location") == ["#{@url}/#{id}"]

    assert conn |> get("#{@url}/#{id}") |> body() == survey
    assert %{"items" => items, "limit" => 50, "offset" => 0} = conn |> get(@url) |> body()
    assert survey in items
  end

  test "created_at is an ISO 8601 timestamp set by the database", %{conn: conn} do
    %{"created_at" => created_at} = conn |> post_json(@url, %{title: "t"}) |> body()
    assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(created_at)
  end

  test "validation failures and missing surveys", %{conn: conn} do
    assert conn |> get("#{@url}/0") |> problem(404)
    assert conn |> get("#{@url}/#{2 ** 31}") |> problem(404)
    assert conn |> get("#{@url}/abc") |> problem(404)
    assert conn |> post_json(@url, %{title: ""}) |> problem(400)
    assert conn |> post_json(@url, %{title: "x", extra: 1}) |> problem(400)
    assert conn |> post_json(@url, %{title: 5}) |> problem(400)
    assert conn |> post_json(@url, %{}) |> problem(400)
    assert conn |> post_json(@url, %{title: String.duplicate("x", 201)}) |> problem(400)
    assert conn |> request(:post, @url, "title=x", "text/plain") |> problem(415)

    assert conn
           |> request(:post, @url, "title=x", "application/x-www-form-urlencoded")
           |> problem(415)
  end

  test "a missing survey names the id in the detail", %{conn: conn} do
    assert %{"detail" => detail} = conn |> get("#{@url}/999999999") |> problem(404)
    assert detail =~ "999999999"
  end

  test "title length is counted in characters, not bytes", %{conn: conn} do
    assert conn |> post_json(@url, %{title: String.duplicate("é", 200)}) |> Map.get(:status) ==
             201

    assert conn |> post_json(@url, %{title: String.duplicate("😀", 200)}) |> Map.get(:status) ==
             201

    assert conn |> post_json(@url, %{title: String.duplicate("é", 201)}) |> problem(400)
  end

  test "a NUL character is a 400, not a database error", %{conn: conn} do
    assert conn |> post_json(@url, %{title: "a\u0000b"}) |> problem(400)
  end

  test "pagination parameters are strict", %{conn: conn} do
    assert conn |> get("#{@url}?limit=1_0") |> problem(400)
    assert conn |> get("#{@url}?offset=%2B1") |> problem(400)
    assert conn |> get("#{@url}?limit[]=1") |> problem(400)
    assert conn |> get("#{@url}?limit=2&offset=0") |> Map.get(:status) == 200
  end

  test "paging walks the whole list", %{conn: conn} do
    ids =
      for n <- 1..5, do: conn |> post_json(@url, %{title: "s#{n}"}) |> body() |> Map.fetch!("id")

    page = conn |> get("#{@url}?limit=2&offset=0") |> body()
    assert length(page["items"]) == 2 and page["next_offset"] == 2

    last = conn |> get("#{@url}?limit=200&offset=#{length(ids) - 1}") |> body()
    assert last["next_offset"] == nil
  end

  test "the body may use a +json media type or a charset parameter", %{conn: conn} do
    for type <- [
          "application/json; charset=utf-8",
          "application/vnd.api+json",
          "APPLICATION/JSON"
        ] do
      assert conn |> request(:post, @url, %{title: "t"}, type) |> Map.get(:status) == 201
    end
  end

  test "the request body limit is 64 KiB", %{conn: conn} do
    padded = fn size ->
      json = ~s({"title":"t"})
      json <> String.duplicate(" ", size - byte_size(json))
    end

    assert conn |> request(:post, @url, padded.(64 * 1024)) |> Map.get(:status) == 201
    assert conn |> request(:post, @url, padded.(64 * 1024 + 1)) |> problem(413)
  end

  test "malformed and non-object bodies are a 400", %{conn: conn} do
    for raw <- ["{nope", "", "[1]", "null", ~s("title"), "42"] do
      assert %{"errors" => %{"body" => _}} = conn |> request(:post, @url, raw) |> problem(400)
    end
  end
end
