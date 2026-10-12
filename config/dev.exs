import Config

# The database comes from DATABASE_URL (see config/runtime.exs); there is deliberately no default.

config :survey_api, SurveyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: false,
  secret_key_base:
    "dev-only-secret-key-base-dev-only-secret-key-base-dev-only-secret-key-base-0000",
  watchers: []

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
