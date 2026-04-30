defmodule Elixdo.Lists do
  @moduledoc "Public API for list operations. Routes through per-date GenServer."

  alias Elixdo.Lists.{Server, ServerPool, DB}

  def get_items_for_date(date) do
    _pid = ServerPool.get_or_start(date)
    Server.get_items(date)
  end

  def get_items_for_range(from_date, to_date, statuses \\ nil) do
    DB.get_items_for_range(from_date, to_date, statuses)
  end

  def create_items(date, attrs) do
    _pid = ServerPool.get_or_start(date)
    Server.create_items(date, attrs)
  end

  def update_item(item, attrs) do
    _pid = ServerPool.get_or_start(item.date)
    Server.update_item(item.date, item, attrs)
  end

  def arrow_item(item, to_date) do
    _pid = ServerPool.get_or_start(item.date)
    Server.arrow_item(item.date, item, to_date)
  end

  def reorder_items(date, ids) do
    _pid = ServerPool.get_or_start(date)
    Server.reorder_items(date, ids)
  end
end
