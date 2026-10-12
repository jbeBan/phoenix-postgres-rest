defmodule SurveyApi.Responses do
  @moduledoc "Responses: one respondent's rating (and comment) for a survey."

  import Ecto.Query

  alias SurveyApi.Limits
  alias SurveyApi.Repo
  alias SurveyApi.Responses.Response
  alias SurveyApi.Validation

  def validate_new(body) do
    Validation.validate(body,
      survey_id: {:int, 1, Limits.int32_max()},
      respondent: :trimmed_text,
      rating: {:int, 1, 5},
      comment: {:optional, {:text, 2000}}
    )
  end

  @doc "`{:error, {:unprocessable, errors}}` when the survey does not exist."
  def create(attrs) do
    case %Response{} |> Response.changeset(attrs) |> Repo.insert() do
      {:ok, response} -> {:ok, response}
      {:error, changeset} -> {:error, {:unprocessable, changeset_errors(changeset)}}
    end
  end

  def get(id), do: Repo.get(Response, id)

  @doc "Up to `limit + 1` responses in id order, optionally for one survey (see the index in the migration)."
  def list(survey_id, limit, offset) do
    query = from r in Response, order_by: r.id, limit: ^(limit + 1), offset: ^offset
    query = if survey_id, do: where(query, [r], r.survey_id == ^survey_id), else: query
    Repo.all(query)
  end

  defp changeset_errors(changeset) do
    Map.new(changeset.errors, fn {field, {message, _opts}} -> {Atom.to_string(field), message} end)
  end
end
