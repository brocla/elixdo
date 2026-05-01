defmodule Elixdo.SearchIndexTest do
  # ETS named table, cannot be async
  use Elixdo.DataCase, async: false

  alias Elixdo.{SearchIndex, Lists}

  test "starts and rebuilds from empty DB" do
    # SearchIndex is already started by the app supervisor
    # search on empty DB returns []
    assert [] = SearchIndex.search("anything")
  end

  test "returns results after item is inserted" do
    {:ok, _} = Lists.create_items(~D[2026-09-01], [%{body: "buy groceries"}])
    # allow async rebuild to settle or use index_item directly
    Process.sleep(50)
    results = SearchIndex.search("groceries")
    assert length(results) >= 1
    assert Enum.any?(results, fn {_id, _date, body} -> String.contains?(body, "groceries") end)
  end

  test "incremental index_item updates ETS without rebuild" do
    item = %Elixdo.ListItem{id: 9999, date: ~D[2026-06-01], body: "unique xyzzy term"}
    SearchIndex.index_item(item)
    Process.sleep(10)
    results = SearchIndex.search("xyzzy")
    assert Enum.any?(results, fn {id, _, _} -> id == 9999 end)
  end
end
