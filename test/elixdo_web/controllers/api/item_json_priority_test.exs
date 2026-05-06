defmodule ElixdoWeb.Api.ItemJSONPriorityTest do
  use Elixdo.DataCase, async: false

  alias ElixdoWeb.Api.ItemJSON
  alias Elixdo.Lists

  @date ~D[2026-08-01]

  test "ItemJSON includes priority field when nil" do
    {:ok, [item]} = Lists.create_items(@date, [%{body: "no priority"}])
    result = ItemJSON.item(item)
    assert Map.has_key?(result, :priority)
    assert result.priority == nil
  end

  test "ItemJSON includes priority field when set" do
    {:ok, [item]} = Lists.create_items(@date, [%{body: "has priority", priority: "❶"}])
    result = ItemJSON.item(item)
    assert result.priority == "❶"
  end
end
