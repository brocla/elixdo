defmodule Elixdo.Repo.Migrations.DropPrefixFromListItems do
  use Ecto.Migration

  def up do
    alter table(:list_items) do
      remove :prefix
    end
  end

  def down do
    alter table(:list_items) do
      add :prefix, :string
    end
  end
end
