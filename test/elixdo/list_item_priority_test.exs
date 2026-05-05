defmodule Elixdo.ListItemPriorityTest do
  use Elixdo.DataCase, async: false

  alias Elixdo.{ListItem, Lists}

  @valid_priorities ["❶", "❷", "❸", "🔥", "⭐"]
  @date ~D[2026-08-01]

  describe "ListItem.changeset/2 priority validation" do
    test "accepts nil priority" do
      attrs = %{date: @date, position: 1, body: "item", priority: nil}
      changeset = ListItem.changeset(%ListItem{}, attrs)
      assert changeset.valid?
    end

    test "accepts each valid priority character" do
      for p <- @valid_priorities do
        attrs = %{date: @date, position: 1, body: "item", priority: p}
        changeset = ListItem.changeset(%ListItem{}, attrs)
        assert changeset.valid?, "expected #{p} to be valid"
      end
    end

    test "rejects an invalid priority character" do
      attrs = %{date: @date, position: 1, body: "item", priority: "X"}
      changeset = ListItem.changeset(%ListItem{}, attrs)
      refute changeset.valid?
      assert %{priority: [_ | _]} = errors_on(changeset)
    end
  end

  describe "arrow_item/2 priority handling" do
    test "arrow copy does not inherit priority" do
      {:ok, [item]} = Lists.create_items(@date, [%{body: "important", priority: "🔥"}])
      {:ok, _original, copy} = Lists.arrow_item(item, ~D[2026-08-02])
      assert copy.priority == nil
    end
  end
end
