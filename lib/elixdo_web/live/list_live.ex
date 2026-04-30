defmodule ElixdoWeb.ListLive do
  use ElixdoWeb, :live_view

  alias Elixdo.{Lists, DateHelper}

  @impl true
  def mount(%{"secret" => secret} = params, _session, socket) do
    date = case params["date"] do
      nil -> Elixdo.Clock.today()
      str ->
        case DateHelper.resolve(str) do
          {:ok, d} -> d
          _ -> Elixdo.Clock.today()
        end
    end
    today = Elixdo.Clock.today()
    items = Lists.get_items_for_date(date)
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Elixdo.PubSub, "date:change")
      Phoenix.PubSub.subscribe(Elixdo.PubSub, "list:#{date}")
    end
    {:ok, socket
      |> assign(:secret, secret)
      |> assign(:date, date)
      |> assign(:today, today)
      |> assign(:items, items)
      |> assign(:selected, MapSet.new())
      |> assign(:editing_id, nil)
      |> assign(:arrow_modal, false)
      |> assign(:arrow_item_ids, [])}
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    case DateHelper.resolve(date_str) do
      {:ok, date} ->
        items = Lists.get_items_for_date(date)
        if connected?(socket) do
          Phoenix.PubSub.unsubscribe(Elixdo.PubSub, "list:#{socket.assigns.date}")
          Phoenix.PubSub.subscribe(Elixdo.PubSub, "list:#{date}")
        end
        {:noreply, socket |> assign(:date, date) |> assign(:items, items) |> assign(:selected, MapSet.new())}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("prev_day", _, socket) do
    {:noreply, push_patch(socket, to: date_path(socket, Date.add(socket.assigns.date, -1)))}
  end

  def handle_event("next_day", _, socket) do
    {:noreply, push_patch(socket, to: date_path(socket, Date.add(socket.assigns.date, 1)))}
  end

  def handle_event("jump_date", %{"date" => date_str}, socket) do
    case DateHelper.resolve(date_str) do
      {:ok, date} -> {:noreply, push_patch(socket, to: date_path(socket, date))}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("go_today", _, socket) do
    {:noreply, push_patch(socket, to: date_path(socket, Elixdo.Clock.today()))}
  end

  def handle_event("key_nav", %{"key" => "ArrowLeft"}, socket) do
    {:noreply, push_patch(socket, to: date_path(socket, Date.add(socket.assigns.date, -1)))}
  end

  def handle_event("key_nav", %{"key" => "ArrowRight"}, socket) do
    {:noreply, push_patch(socket, to: date_path(socket, Date.add(socket.assigns.date, 1)))}
  end

  def handle_event("key_nav", _, socket), do: {:noreply, socket}

  # Selection
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected
    selected = if MapSet.member?(selected, id),
      do: MapSet.delete(selected, id),
      else: MapSet.put(selected, id)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("select_all", _, socket) do
    all_ids = socket.assigns.items |> Enum.map(& &1.id) |> MapSet.new()
    {:noreply, assign(socket, :selected, all_ids)}
  end

  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, :selected, MapSet.new())}
  end

  # Add item
  def handle_event("add_item", %{"body" => body}, socket) do
    body = String.trim(body)
    if body != "" do
      Lists.create_items(socket.assigns.date, [%{body: body}])
      items = Lists.get_items_for_date(socket.assigns.date)
      {:noreply, assign(socket, items: items, selected: MapSet.new())}
    else
      {:noreply, socket}
    end
  end

  # Inline edit
  def handle_event("start_edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_id, String.to_integer(id))}
  end

  def handle_event("save_edit", %{"_id" => id, "body" => body}, socket) do
    id = String.to_integer(id)
    body = String.trim(body)
    if body != "" do
      item = Enum.find(socket.assigns.items, & &1.id == id)
      if item, do: Lists.update_item(item, %{body: body})
      items = Lists.get_items_for_date(socket.assigns.date)
      {:noreply, assign(socket, items: items, editing_id: nil)}
    else
      {:noreply, assign(socket, :editing_id, nil)}
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_id, nil)}
  end

  # Toolbar status actions (apply to all selected)
  def handle_event("set_status", %{"status" => status_str}, socket) do
    status = String.to_existing_atom(status_str)
    selected_items = Enum.filter(socket.assigns.items, & MapSet.member?(socket.assigns.selected, &1.id))
    Enum.each(selected_items, fn item ->
      Lists.update_item(item, %{status: status})
    end)
    items = Lists.get_items_for_date(socket.assigns.date)
    {:noreply, assign(socket, :items, items)}
  end

  # Toolbar decoration actions
  def handle_event("set_decoration", %{"field" => field, "setting" => setting}, socket) do
    selected_items = Enum.filter(socket.assigns.items, & MapSet.member?(socket.assigns.selected, &1.id))
    attrs = case field do
      "bold"        -> %{bold: setting == "true"}
      "italic"      -> %{italic: setting == "true"}
      "highlighted" -> %{highlighted: setting == "true"}
      "color"       -> %{color: if(setting == "", do: nil, else: String.to_existing_atom(setting))}
      "prefix"      -> %{prefix: if(setting == "", do: nil, else: setting)}
      _             -> %{}
    end
    Enum.each(selected_items, fn item ->
      Lists.update_item(item, attrs)
    end)
    items = Lists.get_items_for_date(socket.assigns.date)
    {:noreply, assign(socket, :items, items)}
  end

  # Arrow-out flow
  def handle_event("arrow_selected", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected)
    if selected_ids != [] do
      {:noreply, assign(socket, arrow_modal: true, arrow_item_ids: selected_ids)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("confirm_arrow", %{"to_date" => to_date_str}, socket) do
    case Elixdo.DateHelper.resolve(to_date_str) do
      {:ok, to_date} ->
        Enum.each(socket.assigns.arrow_item_ids, fn id ->
          item = Enum.find(socket.assigns.items, & &1.id == id)
          if item && item.status == :active do
            Lists.arrow_item(item, to_date)
          end
        end)
        items = Lists.get_items_for_date(socket.assigns.date)
        {:noreply, assign(socket, items: items, arrow_modal: false, arrow_item_ids: [], selected: MapSet.new())}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_arrow", _, socket) do
    {:noreply, assign(socket, arrow_modal: false, arrow_item_ids: [])}
  end

  @impl true
  def handle_info({:new_day, new_date}, socket) do
    {:noreply, assign(socket, :today, new_date)}
  end

  def handle_info({:list_updated, date, items}, socket) do
    if date == socket.assigns.date do
      {:noreply, assign(socket, :items, items)}
    else
      {:noreply, socket}
    end
  end

  defp date_path(socket, date) do
    secret = socket.assigns.secret
    ~p"/#{secret}/list/#{Date.to_iso8601(date)}"
  end

  defp item_class(%{status: :completed}),   do: "completed"
  defp item_class(%{status: :wiggled_out}), do: "wiggled-out"
  defp item_class(%{status: :arrowed_out}), do: "arrowed-out"
  defp item_class(_),                        do: "active"

  defp item_classes(item) do
    [
      item_class(item),
      (if item.bold,        do: "bold",        else: nil),
      (if item.italic,      do: "italic",      else: nil),
      (if item.highlighted, do: "highlighted", else: nil),
      color_class(item.color)
    ] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp color_class(nil),     do: nil
  defp color_class(:red),    do: "color-red"
  defp color_class(:blue),   do: "color-blue"
  defp color_class(:green),  do: "color-green"
  defp color_class(:purple), do: "color-purple"
  defp color_class(:orange), do: "color-orange"
end
