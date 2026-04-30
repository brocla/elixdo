defmodule Elixdo.ListsTest do
  use Elixdo.DataCase, async: false

  alias Elixdo.Lists

  @date ~D[2026-05-01]
  @date2 ~D[2026-05-02]
  @date3 ~D[2026-05-03]

  defp insert_item(attrs \\ %{}) do
    defaults = %{body: "test item", date: @date}
    {:ok, [item]} = Lists.create_items(attrs[:date] || @date, [Map.merge(defaults, attrs)])
    item
  end

  describe "get_items_for_date/1" do
    test "returns empty list when no items" do
      assert [] = Lists.get_items_for_date(@date)
    end

    test "returns items for the given date" do
      item = insert_item(%{body: "buy milk"})
      assert [fetched] = Lists.get_items_for_date(@date)
      assert fetched.id == item.id
      assert fetched.body == "buy milk"
    end

    test "does not return items for other dates" do
      insert_item(%{date: @date2, body: "other day"})
      assert [] = Lists.get_items_for_date(@date)
    end

    test "returns items ordered by position" do
      {:ok, items} = Lists.create_items(@date, [
        %{body: "first"},
        %{body: "second"},
        %{body: "third"}
      ])
      positions = Enum.map(items, & &1.position)
      assert positions == Enum.sort(positions)
    end
  end

  describe "get_items_for_range/3" do
    test "returns items within the date range" do
      insert_item(%{date: @date, body: "day 1"})
      insert_item(%{date: @date2, body: "day 2"})
      insert_item(%{date: @date3, body: "day 3"})

      results = Lists.get_items_for_range(@date, @date2)
      bodies = Enum.map(results, & &1.body)
      assert "day 1" in bodies
      assert "day 2" in bodies
      refute "day 3" in bodies
    end

    test "filters by status when provided" do
      item = insert_item(%{date: @date, body: "active item"})
      {:ok, completed} = Lists.update_item(item, %{status: :completed})

      active_results = Lists.get_items_for_range(@date, @date, [:active])
      completed_results = Lists.get_items_for_range(@date, @date, [:completed])

      assert Enum.any?(active_results, & &1.id == item.id) == false
      assert Enum.any?(completed_results, & &1.id == completed.id)
    end

    test "returns all statuses when no filter" do
      item = insert_item(%{date: @date, body: "item"})
      {:ok, _} = Lists.update_item(item, %{status: :completed})

      results = Lists.get_items_for_range(@date, @date)
      assert length(results) == 1
    end
  end

  describe "create_items/2" do
    test "creates a single item" do
      assert {:ok, [item]} = Lists.create_items(@date, [%{body: "new item"}])
      assert item.body == "new item"
      assert item.date == @date
      assert item.position == 1
    end

    test "creates multiple items atomically" do
      assert {:ok, items} = Lists.create_items(@date, [
        %{body: "item 1"},
        %{body: "item 2"},
        %{body: "item 3"}
      ])
      assert length(items) == 3
      positions = Enum.map(items, & &1.position)
      assert positions == [1, 2, 3]
    end

    test "appends after existing items" do
      {:ok, [existing]} = Lists.create_items(@date, [%{body: "existing"}])
      assert {:ok, [new_item]} = Lists.create_items(@date, [%{body: "new"}])
      assert new_item.position == existing.position + 1
    end

    test "returns error for invalid attrs" do
      assert {:error, _changeset} = Lists.create_items(@date, [%{body: ""}])
    end

    test "is atomic - all fail if one is invalid" do
      result = Lists.create_items(@date, [%{body: "valid"}, %{body: ""}])
      assert {:error, _} = result
      assert [] = Lists.get_items_for_date(@date)
    end
  end

  describe "update_item/2" do
    test "updates body" do
      item = insert_item(%{body: "old body"})
      assert {:ok, updated} = Lists.update_item(item, %{body: "new body"})
      assert updated.body == "new body"
    end

    test "allows valid status transition active -> completed" do
      item = insert_item()
      assert {:ok, updated} = Lists.update_item(item, %{status: :completed})
      assert updated.status == :completed
    end

    test "allows valid status transition active -> wiggled_out" do
      item = insert_item()
      assert {:ok, updated} = Lists.update_item(item, %{status: :wiggled_out})
      assert updated.status == :wiggled_out
    end

    test "allows valid status transition completed -> active" do
      item = insert_item()
      {:ok, completed} = Lists.update_item(item, %{status: :completed})
      assert {:ok, reactivated} = Lists.update_item(completed, %{status: :active})
      assert reactivated.status == :active
    end

    test "allows valid status transition wiggled_out -> active" do
      item = insert_item()
      {:ok, wiggled} = Lists.update_item(item, %{status: :wiggled_out})
      assert {:ok, reactivated} = Lists.update_item(wiggled, %{status: :active})
      assert reactivated.status == :active
    end

    test "forbids invalid transition active -> active" do
      item = insert_item()
      assert {:error, :forbidden_transition} = Lists.update_item(item, %{status: :active})
    end

    test "forbids invalid transition completed -> completed" do
      item = insert_item()
      {:ok, completed} = Lists.update_item(item, %{status: :completed})
      assert {:error, :forbidden_transition} = Lists.update_item(completed, %{status: :completed})
    end

    test "forbids arrowed_out -> anything" do
      item = insert_item()
      {:ok, arrowed} = Lists.update_item(item, %{status: :arrowed_out})
      assert {:error, :forbidden_transition} = Lists.update_item(arrowed, %{status: :active})
    end

    test "accepts string status" do
      item = insert_item()
      assert {:ok, updated} = Lists.update_item(item, %{"status" => "completed"})
      assert updated.status == :completed
    end
  end

  describe "arrow_item/2" do
    test "creates copy on target date and marks original as arrowed_out" do
      item = insert_item(%{body: "arrow this", date: @date})
      assert {:ok, original, copy} = Lists.arrow_item(item, @date2)
      assert original.status == :arrowed_out
      assert original.arrowed_to_date == @date2
      assert copy.date == @date2
      assert copy.body == "arrow this"
      assert copy.status == :active
    end

    test "preserves item formatting on copy" do
      {:ok, [item]} = Lists.create_items(@date, [%{
        body: "formatted",
        bold: true,
        italic: true,
        highlighted: true
      }])
      assert {:ok, _original, copy} = Lists.arrow_item(item, @date2)
      assert copy.bold == true
      assert copy.italic == true
      assert copy.highlighted == true
    end

    test "forbids arrow on completed item" do
      item = insert_item()
      {:ok, completed} = Lists.update_item(item, %{status: :completed})
      assert {:error, :forbidden_transition} = Lists.arrow_item(completed, @date2)
    end

    test "forbids arrow on wiggled_out item" do
      item = insert_item()
      {:ok, wiggled} = Lists.update_item(item, %{status: :wiggled_out})
      assert {:error, :forbidden_transition} = Lists.arrow_item(wiggled, @date2)
    end
  end

  describe "reorder_items/2" do
    test "reorders items by given id list" do
      {:ok, [a, b, c]} = Lists.create_items(@date, [
        %{body: "a"}, %{body: "b"}, %{body: "c"}
      ])
      assert {:ok, reordered} = Lists.reorder_items(@date, [c.id, a.id, b.id])
      [first, second, third] = reordered
      assert first.id == c.id
      assert second.id == a.id
      assert third.id == b.id
    end

    test "rejects partial reorder" do
      {:ok, [a, _b]} = Lists.create_items(@date, [%{body: "a"}, %{body: "b"}])
      assert {:error, :partial_reorder} = Lists.reorder_items(@date, [a.id])
    end

    test "rejects reorder with extra ids" do
      {:ok, [a, b]} = Lists.create_items(@date, [%{body: "a"}, %{body: "b"}])
      assert {:error, :partial_reorder} = Lists.reorder_items(@date, [a.id, b.id, 99999])
    end
  end
end
