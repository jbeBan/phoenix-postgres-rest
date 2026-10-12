defmodule SurveyApiWeb.QueryParams do
  @moduledoc """
  Integer parsing for query and path parameters. Values must be plain ASCII integers: `Integer.parse/1`
  alone would also accept `"+5"` and trailing garbage is checked separately, so a regex gates it first.
  """

  alias SurveyApi.Limits

  @default_limit 50
  @max_limit 200
  @plain_int ~r/\A-?[0-9]+\z/

  @doc """
  `{:ok, int | default}` or `{:error, message}` for the named parameter.
  An absent parameter yields the default; a repeated parameter (`a[]=1`) is not an integer.
  """
  def int(params, name, min, max, default \\ nil) do
    case Map.fetch(params, name) do
      :error -> {:ok, default}
      {:ok, raw} -> parse(raw, min, max)
    end
  end

  defp parse(raw, min, max) when is_binary(raw) do
    if Regex.match?(@plain_int, raw) do
      value = String.to_integer(raw)

      if value >= min and value <= max,
        do: {:ok, value},
        else: {:error, "must be between #{min} and #{max}"}
    else
      {:error, "must be an integer"}
    end
  end

  defp parse(_raw, _min, _max), do: {:error, "must be an integer"}

  @doc """
  Parses `limit` and `offset` plus any `extra` integers given as `name: {min, max}` (no default, so absent
  means `nil`). Returns `{:ok, %{limit:, offset:, name => value | nil}}` or `{:error, {:query, errors}}`.
  """
  def paging(params, extra \\ []) do
    fields =
      [
        limit: int(params, "limit", 1, @max_limit, @default_limit),
        offset: int(params, "offset", 0, Limits.int32_max(), 0)
      ] ++
        for({name, {min, max}} <- extra, do: {name, int(params, Atom.to_string(name), min, max)})

    case for({name, {:error, message}} <- fields, into: %{}, do: {Atom.to_string(name), message}) do
      errors when map_size(errors) > 0 -> {:error, {:query, errors}}
      _ -> {:ok, Map.new(fields, fn {name, {:ok, value}} -> {name, value} end)}
    end
  end

  @doc """
  A path id, or `:error` when it can't exist (not an integer, or outside `1..max`) so the caller answers 404
  instead of letting Postgres reject the value.
  """
  def path_id(raw, max) do
    case int(%{"id" => raw}, "id", 1, max) do
      {:ok, id} -> {:ok, id}
      {:error, _message} -> :error
    end
  end

  @doc "The fallback-controller error for an id that doesn't exist (or can't, see `path_id/2`)."
  def not_found(kind, raw_id),
    do: {:error, {:not_found, "#{kind} #{String.slice(raw_id, 0, 40)} not found"}}
end
