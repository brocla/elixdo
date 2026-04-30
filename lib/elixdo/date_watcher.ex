defmodule Elixdo.DateWatcher do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    schedule_midnight()
    {:ok, %{}}
  end

  def handle_info(:midnight, state) do
    new_date = Elixdo.Clock.today()
    Phoenix.PubSub.broadcast(Elixdo.PubSub, "date:change", {:new_day, new_date})
    schedule_midnight()
    {:noreply, state}
  end

  defp schedule_midnight do
    ms = ms_until_midnight()
    Process.send_after(self(), :midnight, ms)
  end

  def ms_until_midnight do
    now = DateTime.now!("America/Denver")
    tomorrow = now |> DateTime.to_date() |> Date.add(1)
    midnight = DateTime.new!(tomorrow, ~T[00:00:00], "America/Denver")
    DateTime.diff(midnight, now, :millisecond)
  end
end
