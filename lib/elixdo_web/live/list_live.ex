defmodule ElixdoWeb.ListLive do
  use ElixdoWeb, :live_view

  alias Elixdo.{Lists, DateHelper, Emoji}

  @impl true
  def mount(%{"secret" => secret} = params, _session, socket) do
    date =
      case params["date"] do
        nil ->
          Elixdo.Clock.today()

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

    {:ok,
     socket
     |> assign(:secret, secret)
     |> assign(:date, date)
     |> assign(:today, today)
     |> assign(:items, items)
     |> assign(:selected, MapSet.new())
     |> assign(:editing_id, nil)
     |> assign(:arrow_modal, false)
     |> assign(:arrow_item_ids, [])
     |> assign(:search_open, false)
     |> assign(:search_results, [])
     |> assign(:highlighted_item_id, nil)}
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

        {:noreply,
         socket |> assign(:date, date) |> assign(:items, items) |> assign(:selected, MapSet.new())}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("prev_day", _, socket) do
    {:noreply,
     socket
     |> assign(:highlighted_item_id, nil)
     |> push_patch(to: date_path(socket, Date.add(socket.assigns.date, -1)))}
  end

  def handle_event("next_day", _, socket) do
    {:noreply,
     socket
     |> assign(:highlighted_item_id, nil)
     |> push_patch(to: date_path(socket, Date.add(socket.assigns.date, 1)))}
  end

  def handle_event("jump_date", %{"date" => date_str}, socket) do
    case DateHelper.resolve(date_str) do
      {:ok, date} ->
        {:noreply,
         socket |> assign(:highlighted_item_id, nil) |> push_patch(to: date_path(socket, date))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("go_today", _, socket) do
    {:noreply,
     socket
     |> assign(:highlighted_item_id, nil)
     |> push_patch(to: date_path(socket, Elixdo.Clock.today()))}
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

    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, socket |> assign(:selected, selected) |> assign(:highlighted_item_id, nil)}
  end

  def handle_event("toggle_all", _, socket) do
    all_ids = socket.assigns.items |> Enum.map(& &1.id) |> MapSet.new()
    selected = if socket.assigns.selected == all_ids, do: MapSet.new(), else: all_ids
    {:noreply, assign(socket, :selected, selected)}
  end

  # Add item
  def handle_event("add_item", %{"body" => body}, socket) do
    body = body |> String.trim() |> Emoji.convert()

    if body != "" do
      Lists.create_items(socket.assigns.date, [%{body: body}])

      {:noreply,
       socket
       |> assign(:selected, MapSet.new())
       |> push_event("clear_add_input", %{})}
    else
      {:noreply, socket}
    end
  end

  # Inline edit
  def handle_event("start_edit", %{"id" => id}, socket) do
    {:noreply,
     socket |> assign(:editing_id, String.to_integer(id)) |> assign(:highlighted_item_id, nil)}
  end

  def handle_event("save_edit", %{"_id" => id, "body" => body}, socket) do
    id = String.to_integer(id)
    body = body |> String.trim() |> Emoji.convert()

    if body != "" do
      item = Enum.find(socket.assigns.items, &(&1.id == id))
      if item, do: Lists.update_item(item, %{body: body})
      {:noreply, assign(socket, :editing_id, nil)}
    else
      {:noreply, assign(socket, :editing_id, nil)}
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_id, nil)}
  end

  # Toolbar status actions (apply to all selected)
  @valid_statuses Ecto.Enum.values(Elixdo.ListItem, :status)
  @valid_status_strings Enum.map(@valid_statuses, &Atom.to_string/1)

  @valid_colors Ecto.Enum.values(Elixdo.ListItem, :color)
  @valid_color_strings Enum.map(@valid_colors, &Atom.to_string/1)

  @valid_priorities ["❶", "❷", "❸", "⭐", "🔥"]

  def handle_event("set_priority", %{"priority" => p}, socket)
      when p in @valid_priorities do
    selected_items =
      Enum.filter(socket.assigns.items, &MapSet.member?(socket.assigns.selected, &1.id))

    Enum.each(selected_items, fn item ->
      Lists.update_item(item, %{priority: p})
    end)

    {:noreply, socket}
  end

  def handle_event("set_status", %{"status" => status_str}, socket)
      when status_str in @valid_status_strings do
    status = String.to_existing_atom(status_str)

    selected_items =
      Enum.filter(socket.assigns.items, &MapSet.member?(socket.assigns.selected, &1.id))

    Enum.each(selected_items, fn item ->
      Lists.update_item(item, %{status: status})
    end)

    {:noreply, socket}
  end

  def handle_event("set_status", _, socket), do: {:noreply, socket}

  # Toolbar decoration actions
  def handle_event("set_decoration", %{"field" => field, "setting" => setting}, socket) do
    selected_items =
      Enum.filter(socket.assigns.items, &MapSet.member?(socket.assigns.selected, &1.id))

    attrs =
      case field do
        "color" when setting == "" -> %{color: nil}
        "color" when setting in @valid_color_strings -> %{color: String.to_existing_atom(setting)}
        "color" -> %{}
        _ -> %{}
      end

    Enum.each(selected_items, fn item ->
      Lists.update_item(item, attrs)
    end)

    {:noreply, socket}
  end

  # Remove all formats + restore active status (except arrowed_out, which cannot transition)
  def handle_event("remove_formats", _, socket) do
    selected_items =
      Enum.filter(socket.assigns.items, &MapSet.member?(socket.assigns.selected, &1.id))

    Enum.each(selected_items, fn item ->
      Lists.update_item(item, %{
        color: nil,
        priority: nil,
        status: :active,
        arrowed_to_date: nil
      })
    end)

    {:noreply, socket}
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
          item = Enum.find(socket.assigns.items, &(&1.id == id))

          if item && item.status == :active do
            Lists.arrow_item(item, to_date)
          end
        end)

        {:noreply,
         assign(socket,
           arrow_modal: false,
           arrow_item_ids: [],
           selected: MapSet.new()
         )}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_arrow", _, socket) do
    {:noreply, assign(socket, arrow_modal: false, arrow_item_ids: [])}
  end

  def handle_event("reorder", %{"order" => ids}, socket) do
    int_ids = Enum.map(ids, &String.to_integer(to_string(&1)))
    Lists.reorder_items(socket.assigns.date, int_ids)
    {:noreply, socket}
  end

  def handle_event("sort_active", _, socket) do
    {active, non_active} =
      Enum.split_with(socket.assigns.items, &(&1.status == :active))

    new_ids = Enum.map(active ++ non_active, & &1.id)
    Lists.reorder_items(socket.assigns.date, new_ids)
    {:noreply, socket}
  end

  # Search
  def handle_event("open_search", _, socket) do
    {:noreply, assign(socket, search_open: true, search_results: [])}
  end

  def handle_event("close_search", _, socket) do
    {:noreply, assign(socket, search_open: false)}
  end

  def handle_event("search", %{"query" => q}, socket) do
    results =
      if String.trim(q) == "" do
        []
      else
        Elixdo.SearchIndex.search(q)
        |> Enum.map(fn {id, date, body} -> %{id: id, date: date, body: body} end)
      end

    {:noreply, assign(socket, search_results: results, search_open: true)}
  end

  def handle_event("goto_result", %{"id" => id, "date" => date_str}, socket) do
    item_id = String.to_integer(id)

    socket =
      socket
      |> assign(search_open: false, highlighted_item_id: item_id)
      |> push_patch(to: date_path(socket, Date.from_iso8601!(date_str)))

    {:noreply, socket}
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

  defp item_class(%{status: :completed}), do: "completed"
  defp item_class(%{status: :wiggled_out}), do: "wiggled-out"
  defp item_class(%{status: :arrowed_out}), do: "arrowed-out"
  defp item_class(_), do: "active"

  defp item_classes(item) do
    [item_class(item), color_class(item.color)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp color_class(nil), do: nil
  defp color_class(:red), do: "color-red"
  defp color_class(:blue), do: "color-blue"
  defp color_class(:green), do: "color-green"
  defp color_class(:purple), do: "color-purple"
  defp color_class(:orange), do: "color-orange"

  defp color_item_class(%{color: nil}), do: nil
  defp color_item_class(%{color: color}), do: "color-#{color}"
end
