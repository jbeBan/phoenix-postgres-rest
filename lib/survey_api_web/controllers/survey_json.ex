defmodule SurveyApiWeb.SurveyJSON do
  alias SurveyApi.Surveys.Survey
  alias SurveyApiWeb.Page

  def index(%{rows: rows, limit: limit, offset: offset}),
    do: Page.render(rows, limit, offset, &data/1)

  def show(%{survey: survey}), do: data(survey)

  defp data(%Survey{} = s) do
    %{id: s.id, title: s.title, created_at: DateTime.to_iso8601(s.created_at)}
  end
end
