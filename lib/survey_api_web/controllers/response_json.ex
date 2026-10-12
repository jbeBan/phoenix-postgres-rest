defmodule SurveyApiWeb.ResponseJSON do
  alias SurveyApi.Responses.Response
  alias SurveyApiWeb.Page

  def index(%{rows: rows, limit: limit, offset: offset}),
    do: Page.render(rows, limit, offset, &data/1)

  def show(%{response: response}), do: data(response)

  defp data(%Response{} = r) do
    %{
      id: r.id,
      survey_id: r.survey_id,
      respondent: r.respondent,
      rating: r.rating,
      comment: r.comment,
      created_at: DateTime.to_iso8601(r.created_at)
    }
  end
end
