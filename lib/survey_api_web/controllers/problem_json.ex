defmodule SurveyApiWeb.ProblemJSON do
  @moduledoc """
  Renders errors raised outside the controllers (unknown route, bad query string, crashes) as problem+json.
  Configured as the endpoint's `render_errors` view for the "problem+json" format (config/config.exs).

  Only 4xx messages are passed on; a 5xx never exposes details.
  """

  alias SurveyApiWeb.Problem

  def render(template, assigns) do
    status = template |> String.split(".") |> hd() |> String.to_integer()

    if status < 500 do
      Problem.body(status, nil, detail: detail(status, assigns[:reason]))
    else
      Problem.body(status, nil, detail_for_5xx(status))
    end
  end

  defp detail(404, _reason), do: "The requested URL was not found on the server."
  defp detail(_status, %{plug_status: _} = reason), do: Exception.message(reason)
  defp detail(status, _reason), do: Problem.reason_phrase(status)

  defp detail_for_5xx(503), do: %{detail: "database is busy or unavailable"}
  defp detail_for_5xx(_status), do: %{}
end
