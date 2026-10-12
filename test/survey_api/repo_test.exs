defmodule SurveyApi.RepoTest do
  use ExUnit.Case, async: true

  alias SurveyApi.Repo

  test "the repo refuses to start without a database url" do
    for config <- [[], [pool_size: 5], [url: nil], [url: ""]] do
      assert_raise RuntimeError, ~r/DATABASE_URL is not set/, fn ->
        Repo.init(:supervisor, config)
      end
    end
  end

  test "a configured url is accepted" do
    config = [url: "postgresql://postgres@localhost/db"]
    assert Repo.init(:supervisor, config) == {:ok, config}
  end

  test "the test configuration has a url" do
    assert {:ok, _} = Repo.init(:supervisor, Application.fetch_env!(:survey_api, Repo))
  end
end
