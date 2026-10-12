defmodule SurveyApiWeb.Router do
  use SurveyApiWeb, :router

  pipeline :api do
    plug :fetch_query_params
    plug :put_format, "json"
  end

  scope "/", SurveyApiWeb do
    pipe_through :api

    get "/healthz", HealthController, :liveness
    get "/readyz", HealthController, :readiness
  end

  scope "/v1", SurveyApiWeb do
    pipe_through :api

    get "/surveys", SurveyController, :index
    post "/surveys", SurveyController, :create
    get "/surveys/:id", SurveyController, :show

    get "/responses", ResponseController, :index
    post "/responses", ResponseController, :create
    get "/responses/:id", ResponseController, :show
  end

  # A known path with another verb is a 405 with an Allow header (HEAD is served by Plug.Head as GET).
  for {path, allow} <- [
        {"/healthz", "GET, HEAD"},
        {"/readyz", "GET, HEAD"},
        {"/v1/surveys", "GET, HEAD, POST"},
        {"/v1/surveys/:id", "GET, HEAD"},
        {"/v1/responses", "GET, HEAD, POST"},
        {"/v1/responses/:id", "GET, HEAD"}
      ] do
    match :*, path, SurveyApiWeb.MethodNotAllowedController, :not_allowed,
      private: %{allow: allow}
  end
end
