defmodule SurveyApiWeb.ResponsesTest do
  use SurveyApiWeb.ConnCase, async: true

  @url "/v1/responses"

  setup %{conn: conn} do
    survey_ids =
      for title <- ["First survey", "Second survey"] do
        conn |> post_json("/v1/surveys", %{title: title}) |> body() |> Map.fetch!("id")
      end

    [survey_id: hd(survey_ids), survey_ids: survey_ids]
  end

  defp valid(survey_id, overrides \\ %{}) do
    Map.merge(
      %{survey_id: survey_id, respondent: "ada@example.com", rating: 5, comment: "great"},
      overrides
    )
  end

  test "create, get and list", %{conn: conn, survey_id: survey_id} do
    created = post_json(conn, @url, valid(survey_id))
    assert created.status == 201
    response = body(created)

    assert %{"id" => id, "rating" => 5, "survey_id" => ^survey_id, "comment" => "great"} =
             response

    assert Plug.Conn.get_resp_header(created, "location") == ["#{@url}/#{id}"]

    assert conn |> get("#{@url}/#{id}") |> body() == response
    page = conn |> get("#{@url}?survey_id=#{survey_id}") |> body()
    assert page == %{"items" => [response], "limit" => 50, "offset" => 0, "next_offset" => nil}
  end

  test "the comment is optional and may be null", %{conn: conn, survey_id: survey_id} do
    for payload <- [Map.delete(valid(survey_id), :comment), valid(survey_id, %{comment: nil})] do
      created = post_json(conn, @url, payload)
      assert created.status == 201
      assert %{"comment" => nil} = body(created)
    end
  end

  test "surrounding whitespace is trimmed from the respondent but kept in the comment", %{
    conn: conn,
    survey_id: sid
  } do
    created = post_json(conn, @url, valid(sid, %{respondent: "  ada  ", comment: "  hi  "}))
    assert %{"respondent" => "ada", "comment" => "  hi  "} = body(created)
  end

  @bad_payloads [
    {%{rating: 6}, ["rating"]},
    {%{rating: 0}, ["rating"]},
    {%{rating: "5"}, ["rating"]},
    {%{rating: true}, ["rating"]},
    {%{rating: 5.0}, ["rating"]},
    {%{survey_id: "1"}, ["survey_id"]},
    {%{id: 99}, ["id"]},
    {%{survey_id: 2 ** 31}, ["survey_id"]},
    {%{respondent: String.duplicate("x", 201)}, ["respondent"]},
    {%{comment: String.duplicate("x", 2001)}, ["comment"]},
    {%{comment: 5}, ["comment"]}
  ]

  for {{overrides, fields}, index} <- Enum.with_index(@bad_payloads) do
    test "validation failure #{index} is a 400 naming #{inspect(fields)}", %{
      conn: conn,
      survey_id: sid
    } do
      resp = post_json(conn, @url, valid(sid, unquote(Macro.escape(overrides))))
      assert %{"errors" => errors} = problem(resp, 400)
      assert Map.keys(errors) == unquote(fields)
      assert conn |> get("#{@url}?survey_id=#{sid}") |> body() |> Map.fetch!("items") == []
    end
  end

  test "every invalid field is reported at once", %{conn: conn} do
    resp = post_json(conn, @url, %{survey_id: 0, respondent: "  "})
    assert %{"errors" => errors} = problem(resp, 400)
    assert Map.keys(errors) |> Enum.sort() == ["rating", "respondent", "survey_id"]
  end

  test "a missing survey_id is reported as a required field", %{conn: conn} do
    assert %{"errors" => %{"survey_id" => "Field required"}} =
             conn |> post_json(@url, %{respondent: "a", rating: 1}) |> problem(400)
  end

  test "ids outside the valid range are a 404, not a 500", %{conn: conn} do
    for id <- ["0", "abc", "-1", "+1", "1_0", "#{2 ** 63}", "99999999999999999999"] do
      assert conn |> get("#{@url}/#{id}") |> problem(404)
    end
  end

  test "a missing id is a 404 that names it", %{conn: conn} do
    assert %{"detail" => detail} = conn |> get("#{@url}/999999999") |> problem(404)
    assert detail =~ "999999999"
  end

  test "the wrong content type is a 415", %{conn: conn} do
    assert conn |> request(:post, @url, "survey_id=1", "text/plain") |> problem(415)
  end

  test "a response for an unknown survey is a 422", %{conn: conn, survey_id: sid} do
    resp = post_json(conn, @url, valid(2 ** 31 - 1))
    assert %{"errors" => %{"survey_id" => "survey does not exist"}} = problem(resp, 422)
    assert conn |> get("#{@url}?survey_id=#{sid}") |> body() |> Map.fetch!("items") == []
  end

  test "boundary values are accepted", %{conn: conn, survey_id: sid} do
    for rating <- [1, 5] do
      payload =
        valid(sid, %{
          rating: rating,
          respondent: String.duplicate("x", 200),
          comment: String.duplicate("x", 2000)
        })

      assert conn |> post_json(@url, payload) |> Map.get(:status) == 201
    end
  end

  test "filtering and paging", %{conn: conn, survey_ids: [first, second]} do
    for sid <- [first, first, second, second, second], do: post_json(conn, @url, valid(sid))

    only_second = conn |> get("#{@url}?survey_id=#{second}") |> body() |> Map.fetch!("items")
    assert length(only_second) == 3 and Enum.all?(only_second, &(&1["survey_id"] == second))

    ids = Enum.map(only_second, & &1["id"])
    assert ids == Enum.sort(ids), "rows come back in id order"

    # 3 rows: a page of 2 has more after it, the last page does not.
    page = conn |> get("#{@url}?survey_id=#{second}&limit=2&offset=0") |> body()
    assert length(page["items"]) == 2 and page["next_offset"] == 2
    page = conn |> get("#{@url}?survey_id=#{second}&limit=2&offset=2") |> body()
    assert length(page["items"]) == 1 and page["next_offset"] == nil

    assert conn |> get("#{@url}?survey_id=#{2 ** 31 - 1}") |> body() |> Map.fetch!("items") == []
  end

  @bad_queries [
    "limit=0",
    "limit=201",
    "offset=-1",
    "offset=#{2 ** 63}",
    "survey_id=abc",
    "survey_id=0",
    "survey_id=#{2 ** 40}",
    # Integer.parse/1 would accept all of these; query parameters must be plain ASCII integers.
    "limit=1_0",
    "limit=%2B5",
    "limit=%205%20",
    "limit=5%0A",
    "limit=%D9%A3",
    "limit=5abc",
    "limit=",
    "offset=1_0",
    "survey_id=1_0"
  ]

  for query <- @bad_queries do
    test "bad query parameters #{inspect(query)} are a 400", %{conn: conn} do
      assert conn |> get("#{@url}?#{unquote(query)}") |> problem(400)
    end
  end

  test "errors name every bad query parameter", %{conn: conn} do
    assert %{"errors" => errors} =
             conn |> get("#{@url}?limit=0&offset=x&survey_id=y") |> problem(400)

    assert Map.keys(errors) |> Enum.sort() == ["limit", "offset", "survey_id"]
  end
end
