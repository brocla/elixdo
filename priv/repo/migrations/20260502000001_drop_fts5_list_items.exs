defmodule Elixdo.Repo.Migrations.DropFts5ListItems do
  use Ecto.Migration

  def up do
    execute "DROP TRIGGER IF EXISTS list_items_ai;"
    execute "DROP TRIGGER IF EXISTS list_items_au;"
    execute "DROP TRIGGER IF EXISTS list_items_ad;"
    execute "DROP TABLE IF EXISTS list_items_fts;"
  end

  def down do
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
