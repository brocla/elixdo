defmodule Elixdo.Repo.Migrations.AddPriorityToListItems do
  use Ecto.Migration

  def change do
    alter table(:list_items) do
      add :priority, :string
    end
  end
end
