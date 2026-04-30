defmodule Elixdo.ListItemTest do
  use Elixdo.DataCase, async: true

  alias Elixdo.ListItem

  test "changeset is valid with required fields" do
    attrs = %{date: ~D[2026-04-29], position: 1, body: "Test item"}
    changeset = ListItem.changeset(%ListItem{}, attrs)
    assert changeset.valid?
  end

  test "changeset is invalid without body" do
    attrs = %{date: ~D[2026-04-29], position: 1}
    changeset = ListItem.changeset(%ListItem{}, attrs)
    refute changeset.valid?
    assert %{body: ["can't be blank"]} = errors_on(changeset)
  end

  test "changeset is invalid without date" do
    attrs = %{position: 1, body: "Test item"}
    changeset = ListItem.changeset(%ListItem{}, attrs)
    refute changeset.valid?
  end

  test "status defaults to active" do
    attrs = %{date: ~D[2026-04-29], position: 1, body: "Test item"}
    changeset = ListItem.changeset(%ListItem{}, attrs)
    assert Ecto.Changeset.get_field(changeset, :status) == :active
  end

  test "rejects invalid status" do
    attrs = %{date: ~D[2026-04-29], position: 1, body: "Test item", status: :invalid}
    changeset = ListItem.changeset(%ListItem{}, attrs)
    refute changeset.valid?
  end

  test "migration ran — can insert and retrieve a list item" do
    {:ok, item} =
      %ListItem{}
      |> ListItem.changeset(%{date: ~D[2026-04-29], position: 1, body: "Migration smoke test"})
      |> Elixdo.Repo.insert()

    assert item.id
    assert item.status == :active
    assert item.body == "Migration smoke test"
  end
end
