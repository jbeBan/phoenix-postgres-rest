defmodule SurveyApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :survey_api

  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :survey_api
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # No Plug.Parsers: request bodies are read by SurveyApiWeb.Plugs.JsonBody, which answers 413/415/400
  # itself. (Plug.Parsers would also wrap non-object JSON under "_json" and merge body fields into params.)
  plug Plug.Head
  plug SurveyApiWeb.Router
end
