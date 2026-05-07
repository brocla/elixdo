defmodule Elixdo.Repo.Migrations.CreatePushSubscriptions do
  use Ecto.Migration

  def change do
    create table(:push_subscriptions) do
      add :device_id, :string, null: false
      add :endpoint, :string, null: false
      add :p256dh, :string, null: false
      add :auth, :string, null: false
      timestamps()
    end

    create unique_index(:push_subscriptions, [:device_id])
    create unique_index(:push_subscriptions, [:endpoint])
  end
end
