defmodule SurveyApi.ApplicationTest do
  use ExUnit.Case, async: true

  alias SurveyApi.Application, as: App

  test "the app refuses to start without a database url" do
    for config <- [[], [pool_size: 5], [url: nil], [url: ""]] do
      assert_raise RuntimeError, ~r/DATABASE_URL is not set/, fn ->
        App.ensure_database_configured!(config)
      end
    end
  end

  test "a configured url is accepted" do
    assert App.ensure_database_configured!(url: "postgresql://postgres@localhost/db") == :ok
  end
end
