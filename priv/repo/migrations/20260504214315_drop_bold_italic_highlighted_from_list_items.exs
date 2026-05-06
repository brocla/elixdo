defmodule Elixdo.Repo.Migrations.DropBoldItalicHighlightedFromListItems do
  use Ecto.Migration

  def up do
    alter table(:list_items) do
      remove :bold
      remove :italic
      remove :highlighted
    end
  end

  def down do
    alter table(:list_items) do
      add :bold, :boolean, null: false, default: false
      add :italic, :boolean, null: false, default: false
      add :highlighted, :boolean, null: false, default: false
    end
  end
end
