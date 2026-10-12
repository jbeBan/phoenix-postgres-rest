import Config

config :survey_api,
  ecto_repos: [SurveyApi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Errors are rendered by SurveyApiWeb.ProblemJSON as application/problem+json (RFC 9457): the custom
# MIME type below makes "problem+json" a Phoenix format, and render_errors points that format at the view.
config :mime, :types, %{"application/problem+json" => ["problem+json"]}

config :phoenix, :format_encoders, json: Jason, "problem+json": Jason

config :survey_api, SurveyApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: ["problem+json": SurveyApiWeb.ProblemJSON],
    layout: false
  ],
  pubsub_server: SurveyApi.PubSub

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
