defmodule SurveyApi.Surveys do
  @moduledoc "Surveys: the things people respond to."

  import Ecto.Query

  alias SurveyApi.Repo
  alias SurveyApi.Surveys.Survey
  alias SurveyApi.Validation

  def validate_new(body), do: Validation.validate(body, title: :trimmed_text)

  def create(attrs) do
    %Survey{} |> Survey.changeset(attrs) |> Repo.insert()
  end

  def get(id), do: Repo.get(Survey, id)

  @doc "Up to `limit + 1` surveys in id order; the extra row tells the caller whether there is a next page."
  def list(limit, offset) do
    Repo.all(from s in Survey, order_by: s.id, limit: ^(limit + 1), offset: ^offset)
  end
end
