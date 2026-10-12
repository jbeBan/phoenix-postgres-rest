defmodule SurveyApi.Repo.Migrations.CreateSurveysAndResponses do
  use Ecto.Migration

  # Hand-written SQL: the CHECK constraints, identity columns and the composite index are easier to read
  # (and to review) as DDL than as Ecto DSL.
  def up do
    execute """
    CREATE TABLE surveys (
        id          INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        title       TEXT         NOT NULL CONSTRAINT surveys_title_check CHECK (char_length(title) BETWEEN 1 AND 200),
        created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
    )
    """

    execute """
    CREATE TABLE responses (
        id          BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        survey_id   INTEGER      NOT NULL REFERENCES surveys (id),
        respondent  TEXT         NOT NULL CONSTRAINT responses_respondent_check CHECK (char_length(respondent) BETWEEN 1 AND 200),
        rating      SMALLINT     NOT NULL CONSTRAINT responses_rating_check CHECK (rating BETWEEN 1 AND 5),
        comment     TEXT         CONSTRAINT responses_comment_check CHECK (char_length(comment) <= 2000),
        created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
    )
    """

    # Serves GET /v1/responses?survey_id=N (filter on survey_id, ordered by id) and the foreign key:
    # rows come back already sorted, so no Sort step. See `mix survey_api.explain` for the plans.
    execute "CREATE INDEX idx_responses_survey_id_id ON responses (survey_id, id)"
  end

  def down do
    execute "DROP TABLE responses"
    execute "DROP TABLE surveys"
  end
end
