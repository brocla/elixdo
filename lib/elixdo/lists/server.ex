defmodule Elixdo.Lists.Server do
  use GenServer
  require Logger

  @flush_interval_ms Application.compile_env(:elixdo, :list_server_flush_ms, 2_000)
  @idle_timeout_ms   Application.compile_env(:elixdo, :list_server_idle_ms, 600_000)

  # Use temporary restart so DynamicSupervisor never auto-restarts these;
  # ServerPool handles on-demand restarts via get_or_start.
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :date)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      type: :worker
    }
  end

  # --- Public API ---

  def start_link(opts) do
    date    = Keyword.fetch!(opts, :date)
    context = Keyword.get(opts, :context, Elixdo.Lists.DB)
    caller  = Keyword.get(opts, :caller, nil)
    GenServer.start_link(__MODULE__, {date, context, caller}, name: via(date))
  end

  def get_items(date),            do: call(date, :get_items)
  def create_items(date, attrs),  do: call(date, {:create_items, attrs})
  def update_item(date, item, attrs), do: call(date, {:update_item, item, attrs})
  def arrow_item(date, item, to), do: call(date, {:arrow_item, item, to})
  def reorder_items(date, ids),   do: call(date, {:reorder_items, ids})

  defp call(date, msg) do
    pid = Elixdo.Lists.ServerPool.get_or_start(date)
    GenServer.call(pid, msg)
  end

  def via(date), do: {:via, Registry, {Elixdo.Lists.Registry, date}}

  # --- Callbacks ---

  def init({date, context, caller}) do
    maybe_allow_sandbox(caller)
    items = context.get_items_for_date(date)
    schedule_idle()
    {:ok, %{date: date, items: items, dirty: false, context: context}}
  end

  def handle_call(:get_items, _from, state) do
    {:reply, state.items, state, {:continue, :reset_idle}}
  end

  def handle_call({:create_items, attrs}, _from, state) do
    case state.context.create_items(state.date, attrs) do
      {:ok, new_items} = result ->
        updated = state.items ++ new_items
        Enum.each(new_items, &Elixdo.SearchIndex.index_item/1)
        broadcast(state.date, updated)
        schedule_flush()
        {:reply, result, %{state | items: updated, dirty: true}, {:continue, :reset_idle}}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:update_item, item, attrs}, _from, state) do
    case state.context.update_item(item, attrs) do
      {:ok, updated_item} = result ->
        items = Enum.map(state.items, fn i ->
          if i.id == updated_item.id, do: updated_item, else: i
        end)
        broadcast(state.date, items)
        schedule_flush()
        {:reply, result, %{state | items: items, dirty: true}, {:continue, :reset_idle}}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:arrow_item, item, to_date}, _from, state) do
    case state.context.arrow_item(item, to_date) do
      {:ok, original, copy} = result ->
        items = Enum.map(state.items, fn i ->
          if i.id == original.id, do: original, else: i
        end)
        Elixdo.SearchIndex.index_item(copy)
        broadcast(state.date, items)
        schedule_flush()
        {:reply, result, %{state | items: items, dirty: true}, {:continue, :reset_idle}}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:reorder_items, ids}, _from, state) do
    case state.context.reorder_items(state.date, ids) do
      {:ok, reordered} = result ->
        broadcast(state.date, reordered)
        schedule_flush()
        {:reply, result, %{state | items: reordered, dirty: true}, {:continue, :reset_idle}}
      error ->
        {:reply, error, state}
    end
  end

  defp broadcast(date, items) do
    Phoenix.PubSub.broadcast(Elixdo.PubSub, "list:#{date}", {:list_updated, date, items})
  end

  def handle_continue(:reset_idle, state) do
    {:noreply, state}
  end

  def handle_info(:flush, %{dirty: false} = state), do: {:noreply, state}
  def handle_info(:flush, state) do
    # State is already persisted via DB context calls — dirty flag just tracks
    # whether we need to broadcast. In this implementation DB writes happen
    # immediately in the context; flush clears the flag.
    {:noreply, %{state | dirty: false}}
  end

  def handle_info(:idle_timeout, state) do
    Logger.debug("Lists.Server shutting down idle process for #{state.date}")
    {:stop, :normal, state}
  end

  def terminate(_reason, state) do
    if state.dirty do
      Logger.debug("Lists.Server flushing on terminate for #{state.date}")
    end
    :ok
  end

  if Mix.env() == :test do
    defp maybe_allow_sandbox(nil), do: :ok
    defp maybe_allow_sandbox(caller) do
      try do
        Ecto.Adapters.SQL.Sandbox.allow(Elixdo.Repo, caller, self())
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end
  else
    defp maybe_allow_sandbox(_caller), do: :ok
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end

  defp schedule_idle do
    Process.send_after(self(), :idle_timeout, @idle_timeout_ms)
  end
end
