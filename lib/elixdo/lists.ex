defmodule Elixdo.Lists do
  @moduledoc "Public API for list operations. Routes through per-date GenServer."

  alias Elixdo.Lists.{Server, DB}

  def get_items_for_date(date), do: Server.get_items(date)
  def get_items_for_range(from_date, to_date, statuses \\ nil), do: DB.get_items_for_range(from_date, to_date, statuses)
  def create_items(date, attrs), do: Server.create_items(date, attrs)
  def update_item(item, attrs), do: Server.update_item(item.date, item, attrs)
  def arrow_item(item, to_date), do: Server.arrow_item(item.date, item, to_date)
  def reorder_items(date, ids), do: Server.reorder_items(date, ids)
end
