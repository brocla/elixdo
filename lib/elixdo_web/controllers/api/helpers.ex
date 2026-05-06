defmodule ElixdoWeb.Api.Helpers do
  alias Elixdo.{Repo, ListItem}

  @doc "Fetch a ListItem by id, returning {:ok, item} or {:error, :not_found}."
  def fetch_item(id) do
    case Repo.get(ListItem, id) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end
end
