defmodule Elixdo.PushSubscription do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "push_subscriptions" do
    field :device_id, :string
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string
    timestamps()
  end

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:device_id, :endpoint, :p256dh, :auth])
    |> validate_required([:device_id, :endpoint, :p256dh, :auth])
    |> unique_constraint(:device_id)
    |> unique_constraint(:endpoint)
  end
end
