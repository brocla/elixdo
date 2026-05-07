defmodule Elixdo.Lists do
  @moduledoc "Public API for list operations. Routes through per-date GenServer."

  alias Elixdo.Lists.{Server, DB}
  alias Elixdo.Emoji

  def get_items_for_date(date), do: Server.get_items(date)

  def get_items_for_range(from_date, to_date, statuses \\ nil),
    do: DB.get_items_for_range(from_date, to_date, statuses)

  def create_items(date, attrs, opts \\ []) do
    attrs = Enum.map(attrs, &convert_body/1)

    case Server.create_items(date, attrs) do
      {:ok, items} = result ->
        unless opts[:suppress_push] do
          device_id = opts[:device_id]

          Enum.each(items, fn item ->
            Elixdo.PushNotifications.notify_devices(item.body, device_id)
          end)
        end

        result

      error ->
        error
    end
  end

  def update_item(item, attrs) do
    attrs = convert_body(attrs)
    Server.update_item(item.date, item, attrs)
  end

  def arrow_item(item, to_date), do: Server.arrow_item(item.date, item, to_date)
  def reorder_items(date, ids), do: Server.reorder_items(date, ids)

  defp convert_body(%{body: body} = attrs), do: %{attrs | body: Emoji.convert(body)}
  defp convert_body(%{"body" => body} = attrs), do: %{attrs | "body" => Emoji.convert(body)}
  defp convert_body(attrs), do: attrs
end
