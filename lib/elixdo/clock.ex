defmodule Elixdo.Clock do
  # Dispatcher module that also owns the behaviour contract — impl swapped via application config.
  @callback today() :: Date.t()
  def today, do: impl().today()
  defp impl, do: Application.get_env(:elixdo, :clock, Elixdo.Clock.System)
end

defmodule Elixdo.Clock.System do
  @behaviour Elixdo.Clock
  def today, do: DateTime.now!("America/Denver") |> DateTime.to_date()
end
