defmodule SurveyApiWeb.Page do
  @moduledoc "The `{items, limit, offset, next_offset}` envelope of every list endpoint."

  @doc "`rows` holds up to `limit + 1` records; the extra one tells us whether there is a next page."
  def render(rows, limit, offset, to_map) do
    %{
      items: rows |> Enum.take(limit) |> Enum.map(to_map),
      limit: limit,
      offset: offset,
      next_offset: if(length(rows) > limit, do: offset + limit)
    }
  end
end
