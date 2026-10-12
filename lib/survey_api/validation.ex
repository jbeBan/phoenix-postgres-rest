defmodule SurveyApi.Validation do
  @moduledoc """
  Strict validation of decoded JSON request bodies. No coercion (`"5"` is not a rating, `5.0` is not an
  integer), unknown fields are rejected, and integers are bounded to the column types, so out-of-range values
  are a 400 rather than a database error.

  A spec is a keyword list of `field: type`:

    * `:trimmed_text` - string, trimmed, 1..200 characters
    * `{:text, max}` - string, at most `max` characters, kept as sent
    * `{:int, min, max}` - integer within the bounds
    * `{:optional, type}` - may be absent or null

  Returns `{:ok, %{field: value}}` or `{:error, {:validation, %{"field" => "message"}}}`; a body that is not an object is
  reported under `"body"`.
  """

  @type spec :: [{atom(), term()}]

  @spec validate(term(), spec()) ::
          {:ok, map()} | {:error, {:validation, %{optional(String.t()) => String.t()}}}
  def validate(body, spec) when is_map(body) do
    known = Map.new(spec, fn {field, _} -> {Atom.to_string(field), field} end)

    unknown =
      for key <- Map.keys(body), not is_map_key(known, key), into: %{} do
        {key, "Extra inputs are not permitted"}
      end

    results =
      for {field, type} <- spec do
        {field, check(type, Map.fetch(body, Atom.to_string(field)))}
      end

    errors =
      Enum.reduce(results, unknown, fn
        {field, {:error, message}}, acc -> Map.put(acc, Atom.to_string(field), message)
        _ok, acc -> acc
      end)

    if map_size(errors) == 0 do
      {:ok,
       for({field, {:ok, value}} <- results, value != :absent, into: %{}, do: {field, value})}
    else
      {:error, {:validation, errors}}
    end
  end

  def validate(_body, _spec),
    do: {:error, {:validation, %{"body" => "Input should be a valid JSON object"}}}

  defp check({:optional, _type}, :error), do: {:ok, :absent}
  defp check({:optional, _type}, {:ok, nil}), do: {:ok, nil}
  defp check({:optional, type}, value), do: check(type, value)
  defp check(_type, :error), do: {:error, "Field required"}

  defp check(:trimmed_text, {:ok, value}) when is_binary(value) do
    check_text(String.trim(value), 1, 200)
  end

  defp check({:text, max}, {:ok, value}) when is_binary(value), do: check_text(value, 0, max)

  defp check({:int, min, max}, {:ok, value}) when is_integer(value) do
    cond do
      value < min -> {:error, "Input should be greater than or equal to #{min}"}
      value > max -> {:error, "Input should be less than or equal to #{max}"}
      true -> {:ok, value}
    end
  end

  defp check({:int, _, _}, {:ok, _}), do: {:error, "Input should be a valid integer"}
  defp check(_text, {:ok, _}), do: {:error, "Input should be a valid string"}

  # Length in code points, which is what Postgres' char_length() counts.
  defp check_text(value, min, max) do
    length = value |> String.to_charlist() |> length()

    cond do
      String.contains?(value, <<0>>) -> {:error, "String cannot contain NUL characters"}
      length < min -> {:error, "String should have at least #{min} character"}
      length > max -> {:error, "String should have at most #{max} characters"}
      true -> {:ok, value}
    end
  end
end
