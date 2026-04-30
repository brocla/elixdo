defmodule Elixdo.Lists.ServerPool do
  def get_or_start(date) do
    case Registry.lookup(Elixdo.Lists.Registry, date) do
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid) do
          pid
        else
          start_new(date)
        end
      [] ->
        start_new(date)
    end
  end

  defp start_new(date) do
    case Elixdo.Lists.Supervisor.start_server(date, caller: self()) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
