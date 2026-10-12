defmodule SurveyApi.Responses.Response do
  use Ecto.Schema
  import Ecto.Changeset

  schema "responses" do
    field :survey_id, :integer
    field :respondent, :string
    field :rating, :integer
    field :comment, :string
    field :created_at, :utc_datetime_usec, read_after_writes: true
  end

  def changeset(response, attrs) do
    response
    |> cast(attrs, [:survey_id, :respondent, :rating, :comment])
    |> validate_required([:survey_id, :respondent, :rating])
    # A well-formed body that points at a survey that does not exist.
    |> foreign_key_constraint(:survey_id,
      name: :responses_survey_id_fkey,
      message: "survey does not exist"
    )
  end
end
