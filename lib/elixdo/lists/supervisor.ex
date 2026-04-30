defmodule Elixdo.Lists.Supervisor do
  use DynamicSupervisor

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_server(date, opts \\ []) do
    spec = {Elixdo.Lists.Server, Keyword.merge([date: date], opts)}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
