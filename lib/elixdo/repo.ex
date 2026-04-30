defmodule Elixdo.Repo do
  use Ecto.Repo,
    otp_app: :elixdo,
    adapter: Ecto.Adapters.SQLite3
end
