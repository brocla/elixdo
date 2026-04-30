defmodule Elixdo.Lists.ServerTest do
  use Elixdo.DataCase, async: false

  alias Elixdo.Lists
  alias Elixdo.Lists.ServerPool

  @test_date ~D[2026-06-15]

  test "GenServer starts on demand and is registered" do
    pid = ServerPool.get_or_start(@test_date)
    assert is_pid(pid)
    assert [{^pid, _}] = Registry.lookup(Elixdo.Lists.Registry, @test_date)
  end

  test "GenServer is supervised under DynamicSupervisor" do
    pid = ServerPool.get_or_start(@test_date)
    children = DynamicSupervisor.which_children(Elixdo.Lists.Supervisor)
    pids = Enum.map(children, fn {_, p, _, _} -> p end)
    assert pid in pids
  end

  test "data persists in SQLite after process kill and restart" do
    # Write via GenServer
    {:ok, [item]} = Lists.create_items(@test_date, [%{body: "persist this"}])
    assert item.id

    # Kill the GenServer process
    pid = ServerPool.get_or_start(@test_date)
    Process.exit(pid, :kill)
    Process.sleep(50)

    # New process starts on next access — reads from SQLite
    items = Lists.get_items_for_date(@test_date)
    assert Enum.any?(items, fn i -> i.body == "persist this" end)
  end

  test "process terminates after idle timeout" do
    date = ~D[2026-07-01]
    pid = ServerPool.get_or_start(date)
    ref = Process.monitor(pid)

    # Wait for idle timeout (test config: 200ms)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end

  test "process restarts automatically after idle shutdown" do
    date = ~D[2026-07-02]
    pid1 = ServerPool.get_or_start(date)
    ref  = Process.monitor(pid1)
    assert_receive {:DOWN, ^ref, :process, ^pid1, :normal}, 1_000

    # Next access starts a new process
    pid2 = ServerPool.get_or_start(date)
    assert is_pid(pid2)
    assert pid1 != pid2
  end
end
