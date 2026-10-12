defmodule SurveyApi.ValidationTest do
  use ExUnit.Case, async: true

  alias SurveyApi.Validation

  @spec_ [name: :trimmed_text, rating: {:int, 1, 5}, note: {:optional, {:text, 5}}]

  defp validate(body), do: Validation.validate(body, @spec_)

  test "valid bodies come back keyed by atom, trimmed, with absent optionals left out" do
    assert validate(%{"name" => "  ada ", "rating" => 3}) == {:ok, %{name: "ada", rating: 3}}

    assert validate(%{"name" => "a", "rating" => 3, "note" => nil}) ==
             {:ok, %{name: "a", rating: 3, note: nil}}

    assert validate(%{"name" => "a", "rating" => 3, "note" => " hi "}) ==
             {:ok, %{name: "a", rating: 3, note: " hi "}}
  end

  test "there is no coercion" do
    for rating <- ["3", 3.0, true, nil, [3], %{}] do
      assert {:error, {:validation, %{"rating" => "Input should be a valid integer"}}} =
               validate(%{"name" => "a", "rating" => rating})
    end

    for name <- [1, true, nil, ["a"]] do
      assert {:error, {:validation, %{"name" => "Input should be a valid string"}}} =
               validate(%{"name" => name, "rating" => 1})
    end
  end

  test "bounds are inclusive and reported with the bound" do
    assert {:ok, _} = validate(%{"name" => "a", "rating" => 1})
    assert {:ok, _} = validate(%{"name" => "a", "rating" => 5})

    assert {:error, {:validation, %{"rating" => "Input should be greater than or equal to 1"}}} =
             validate(%{"name" => "a", "rating" => 0})

    assert {:error, {:validation, %{"rating" => "Input should be less than or equal to 5"}}} =
             validate(%{"name" => "a", "rating" => 6})
  end

  test "a text that is only whitespace is empty after trimming" do
    assert {:error, {:validation, %{"name" => "String should have at least 1 character"}}} =
             validate(%{"name" => " \t\n", "rating" => 1})
  end

  test "length is counted in code points, like Postgres char_length" do
    assert {:ok, _} = validate(%{"name" => String.duplicate("é", 200), "rating" => 1})
    assert {:ok, _} = validate(%{"name" => String.duplicate("😀", 200), "rating" => 1})

    assert {:error, {:validation, %{"name" => _}}} =
             validate(%{"name" => String.duplicate("😀", 201), "rating" => 1})

    # "e" + combining accent is one grapheme but two code points (and two char_length units).
    assert {:error, {:validation, %{"note" => _}}} =
             validate(%{"name" => "a", "rating" => 1, "note" => "ééé"})
  end

  test "NUL characters are rejected, since Postgres text cannot hold them" do
    assert {:error, {:validation, %{"name" => "String cannot contain NUL characters"}}} =
             validate(%{"name" => "a\0b", "rating" => 1})
  end

  test "unknown and missing fields are reported together" do
    assert {:error, {:validation, errors}} = validate(%{"extra" => 1})

    assert errors == %{
             "extra" => "Extra inputs are not permitted",
             "name" => "Field required",
             "rating" => "Field required"
           }
  end

  test "anything but an object is reported under body" do
    for body <- [nil, [], [%{}], "x", 1, true] do
      assert {:error, {:validation, %{"body" => _}}} = validate(body)
    end
  end
end
