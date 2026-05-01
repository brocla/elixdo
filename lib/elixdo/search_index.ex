defmodule Elixdo.SearchIndex do
  use GenServer
  import Ecto.Query
  alias Elixdo.{Repo, ListItem}

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def search(query) when is_binary(query) do
    GenServer.call(__MODULE__, {:search, String.downcase(query)})
  end

  def index_item(%ListItem{} = item) do
    GenServer.cast(__MODULE__, {:index, item})
  end

  def init(_) do
    table = :ets.new(:search_index, [:set, :protected, :named_table, read_concurrency: true])
    send(self(), :rebuild)
    {:ok, %{table: table, ready: false}}
  end

  def handle_info(:rebuild, state) do
    items = Repo.all(from i in ListItem, select: {i.id, i.date, i.body})

    Enum.each(items, fn {id, date, body} ->
      :ets.insert(:search_index, {id, date, String.downcase(body)})
    end)

    {:noreply, %{state | ready: true}}
  end

  def handle_cast({:index, item}, state) do
    :ets.insert(:search_index, {item.id, item.date, String.downcase(item.body)})
    {:noreply, state}
  end

  def handle_call({:search, query}, _from, %{ready: false} = state) do
    results =
      Repo.all(
        from i in ListItem,
          where: like(i.body, ^"%#{query}%"),
          select: {i.id, i.date, i.body}
      )

    {:reply, results, state}
  end

  def handle_call({:search, query}, _from, %{ready: true} = state) do
    results =
      :ets.tab2list(:search_index)
      |> Enum.filter(fn {_id, _date, body} -> String.contains?(body, query) end)
      |> Enum.map(fn {id, date, body} -> {id, date, body} end)

    {:reply, results, state}
  end
end
