import Config

# The test database comes from TEST_DATABASE_URL (see config/runtime.exs).
config :survey_api, SurveyApi.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :survey_api, SurveyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test-only-secret-key-base-test-only-secret-key-base-test-only-secret-key-base-000",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
