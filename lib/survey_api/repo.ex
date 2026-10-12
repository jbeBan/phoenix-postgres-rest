defmodule SurveyApi.Repo do
  use Ecto.Repo,
    otp_app: :survey_api,
    adapter: Ecto.Adapters.Postgres
end
