import Config

# Read from the environment once at startup. There is deliberately no default DATABASE_URL: a missing value
# must stop the process instead of quietly connecting to some localhost database.
#
#   DATABASE_URL      required (dev, prod): ecto://user:password@host:5432/dbname (postgresql:// also works)
#   TEST_DATABASE_URL tests only; defaults to survey_api_test on the local dev cluster (port 5433)
#   DB_POOL_SIZE      connections per node (10). Ecto has no overflow pool: this is the hard cap.
#   DB_QUEUE_TARGET   ms a request may wait for a free connection before the pool starts shedding load (500)
#   PORT              HTTP port (4000)
#   SECRET_KEY_BASE   required in prod (`mix phx.gen.secret`); nothing here uses it yet, Phoenix insists on it
#   PHX_SERVER        set to "true" to start the HTTP server in a release (bin/server does this)

repo_url =
  case config_env() do
    :test ->
      System.get_env("TEST_DATABASE_URL", "postgresql://postgres@localhost:5433/survey_api_test")

    _ ->
      System.get_env("DATABASE_URL")
  end

# This file is also evaluated by `mix compile` and `mix deps.get`, so a missing URL is not an error here:
# SurveyApi.Application refuses to start without one.
repo_config = [
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
  queue_target: String.to_integer(System.get_env("DB_QUEUE_TARGET", "500"))
]

config :survey_api,
       SurveyApi.Repo,
       if(repo_url, do: [{:url, repo_url} | repo_config], else: repo_config)

if System.get_env("PHX_SERVER") do
  config :survey_api, SurveyApiWeb.Endpoint, server: true
end

config :survey_api, SurveyApiWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is not set (generate one with `mix phx.gen.secret`)"

  config :survey_api, SurveyApiWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST", "localhost")],
    # IPv4 on all interfaces: containers often have IPv6 disabled.
    http: [ip: {0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
