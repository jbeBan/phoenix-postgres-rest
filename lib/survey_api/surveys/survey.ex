defmodule SurveyApi.Surveys.Survey do
  use Ecto.Schema
  import Ecto.Changeset

  # id and created_at are filled in by Postgres (identity column, DEFAULT now()) and read back with RETURNING.
  schema "surveys" do
    field :title, :string
    field :created_at, :utc_datetime_usec, read_after_writes: true
  end

  def changeset(survey, attrs) do
    survey
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> check_constraint(:title, name: :surveys_title_check)
  end
end
