defmodule Elixdo.ConfigTest do
  @moduledoc """
  Guards critical configuration values that are easy to accidentally change
  and whose breakage only shows up at deploy time, not during local testing.
  """
  use ExUnit.Case, async: true

  @css File.read!(Path.join(__DIR__, "../assets/css/app.css"))

  test "list-container uses height not min-height so add-item form stays on screen" do
    # min-height: 100dvh lets the container grow beyond the viewport when items
    # are tall, pushing the add-item form off the bottom of the screen.
    # Must be height: 100dvh with items-list scrolling internally.
    refute @css =~ ~r/\.list-container\s*\{[^}]*min-height\s*:\s*100dvh/,
           """
           .list-container must not use min-height: 100dvh — it allows the container
           to grow past the viewport, pushing the add-item form off-screen.
           Use height: 100dvh instead, with .items-list { flex: 1; overflow-y: auto }.
           """

    assert @css =~ ~r/\.list-container\s*\{[^}]*height\s*:\s*100dvh/,
           ".list-container must use height: 100dvh to pin the add-item form at the bottom."

    assert @css =~ ~r/\.items-list\s*\{[^}]*overflow-y\s*:\s*auto/,
           ".items-list must have overflow-y: auto so items scroll within the fixed container."

    assert @css =~ ~r/\.items-list\s*\{[^}]*min-height\s*:\s*0/,
           ".items-list must have min-height: 0 so the flex child can shrink and overflow-y: auto takes effect."
  end

  test "runtime.exs binds IPv6 for Fly.io proxy compatibility" do
    runtime_config = File.read!(Path.join(__DIR__, "../config/runtime.exs"))

    # Fly.io's internal proxy connects to the app over IPv6.
    # {0,0,0,0} (IPv4 only) causes "app not listening on expected address"
    # and makes the deployed app unreachable. Must be the 8-tuple IPv6 form.
    assert runtime_config =~ "{0, 0, 0, 0, 0, 0, 0, 0}",
           """
           config/runtime.exs must bind to IPv6 {0, 0, 0, 0, 0, 0, 0, 0} for Fly.io.
           Using {0, 0, 0, 0} (IPv4) will make the deployed app unreachable.
           """
  end
end
