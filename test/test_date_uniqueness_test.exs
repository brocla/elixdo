defmodule Elixdo.TestDateUniquenessTest do
  @moduledoc """
  Meta-test: asserts that no two test files pass the same hardcoded date to
  create_items/2, arrow_item/2, or get_items_for_date/1.

  Why: tests share a real SQLite DB with no rollback between modules. If two
  files create rows on the same date, selector-ambiguity errors appear:
  "expected selector to return a single element, but got 2".

  Only dates that appear as the first argument of those calls are checked,
  which avoids false positives from clock-mock stubs and in-memory structs.
  """
  use ExUnit.Case, async: true

  # Matches date literals passed as the first argument to DB-writing calls:
  #   create_items(~D[2026-05-01], ...)
  #   arrow_item(item, ~D[2026-05-01])
  #   get_items_for_date(~D[2026-05-01])
  @call_with_date ~r/(?:create_items|arrow_item|get_items_for_date)\([^,)]*?~D\[(\d{4}-\d{2}-\d{2})\]/

  test "no two test files use the same hardcoded date in DB-writing calls" do
    test_files = Path.wildcard(Path.join(__DIR__, "**/*.exs"))

    date_to_files =
      test_files
      |> Enum.flat_map(fn path ->
        content = File.read!(path)

        dates =
          @call_with_date
          |> Regex.scan(content, capture: :all_but_first)
          |> List.flatten()
          |> Enum.uniq()

        short = Path.relative_to(path, __DIR__)
        Enum.map(dates, fn date -> {date, short} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    duplicates =
      date_to_files
      |> Enum.filter(fn {_date, files} -> length(Enum.uniq(files)) > 1 end)
      |> Enum.sort_by(&elem(&1, 0))

    assert duplicates == [],
           "Dates used in multiple test files for DB writes (risk of selector ambiguity):\n\n" <>
             Enum.map_join(duplicates, "\n", fn {date, files} ->
               "  ~D[#{date}]  →  #{Enum.join(Enum.uniq(files), ",  ")}"
             end) <>
             "\n\nFix: assign each date to exactly one test file."
  end
end
