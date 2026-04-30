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
    end
    {:ok, socket
      |> assign(:secret, secret)
      |> assign(:date, date)
      |> assign(:today, today)
      |> assign(:items, items)}
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    case DateHelper.resolve(date_str) do
      {:ok, date} ->
        items = Lists.get_items_for_date(date)
        {:noreply, socket |> assign(:date, date) |> assign(:items, items)}
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

  @impl true
  def handle_info({:new_day, new_date}, socket) do
    {:noreply, assign(socket, :today, new_date)}
  end

  defp date_path(socket, date) do
    secret = socket.assigns.secret
    ~p"/#{secret}/list/#{Date.to_iso8601(date)}"
  end

  defp item_class(%{status: :completed}),   do: "completed"
  defp item_class(%{status: :wiggled_out}), do: "wiggled-out"
  defp item_class(%{status: :arrowed_out}), do: "arrowed-out"
  defp item_class(_),                        do: "active"

  defp format_class(item) do
    [
      (if item.bold,        do: "bold",        else: nil),
      (if item.italic,      do: "italic",      else: nil),
      (if item.highlighted, do: "highlighted", else: nil)
    ] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp color_style(%{color: nil}), do: ""
  defp color_style(%{color: :red}),    do: "color: #E53935;"
  defp color_style(%{color: :blue}),   do: "color: #1E88E5;"
  defp color_style(%{color: :green}),  do: "color: #43A047;"
  defp color_style(%{color: :purple}), do: "color: #8E24AA;"
  defp color_style(%{color: :orange}), do: "color: #FB8C00;"
end
