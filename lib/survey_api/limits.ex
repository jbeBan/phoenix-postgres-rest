defmodule SurveyApi.Limits do
  @moduledoc """
  Largest values the column types can hold; inputs beyond these are rejected up front instead of reaching
  Postgres as "out of range" errors.
  """

  @int32_max 2_147_483_647
  @int64_max 9_223_372_036_854_775_807

  def int32_max, do: @int32_max
  def int64_max, do: @int64_max
end
