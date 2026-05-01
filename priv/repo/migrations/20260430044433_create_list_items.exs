defmodule Elixdo.Repo.Migrations.CreateListItems do
  use Ecto.Migration

  def change do
    create table(:list_items) do
      add :date, :date, null: false
      add :position, :integer, null: false
      add :body, :text, null: false
      add :status, :string, null: false, default: "active"
      add :color, :string
      add :bold, :boolean, null: false, default: false
      add :italic, :boolean, null: false, default: false
      add :highlighted, :boolean, null: false, default: false
      add :prefix, :string
      add :arrowed_to_date, :date

      timestamps(type: :utc_datetime)
    end

    execute "CREATE INDEX idx_list_items_date_position ON list_items (date, position);"

    execute """
    CREATE VIRTUAL TABLE list_items_fts USING fts5(body, content='list_items', content_rowid='id');
    """

    execute """
    CREATE TRIGGER list_items_ai AFTER INSERT ON list_items BEGIN
      INSERT INTO list_items_fts(rowid, body) VALUES (new.id, new.body);
    END;
    """

    execute """
    CREATE TRIGGER list_items_au AFTER UPDATE ON list_items BEGIN
      INSERT INTO list_items_fts(list_items_fts, rowid, body) VALUES ('delete', old.id, old.body);
      INSERT INTO list_items_fts(rowid, body) VALUES (new.id, new.body);
    END;
    """

    execute """
    CREATE TRIGGER list_items_ad AFTER DELETE ON list_items BEGIN
      INSERT INTO list_items_fts(list_items_fts, rowid, body) VALUES ('delete', old.id, old.body);
    END;
    """
  end
end
