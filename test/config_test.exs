defmodule Elixdo.ConfigTest do
  @moduledoc """
  Guards critical configuration values that are easy to accidentally change
  and whose breakage only shows up at deploy time, not during local testing.
  """
  use ExUnit.Case, async: true

  @css File.read!(Path.join(__DIR__, "../assets/css/app.css"))

  test "list-container uses 100svh not 100dvh so add-item form stays on screen" do
    # On Android, 100dvh is computed against the full screen height, including
    # the system navigation bar that overlays web content. This makes the
    # container taller than the visible viewport, pushing the add-item form
    # off screen even with few items.
    # 100svh (small viewport height) is always the safe visible area.
    refute @css =~ ~r/\.list-container\s*\{[^}]*min-height\s*:\s*100dvh/,
           ".list-container must not use min-height: 100dvh — on Android it exceeds the visible viewport."

    assert @css =~ ~r/\.list-container\s*\{[^}]*min-height\s*:\s*100svh/,
           ".list-container must use min-height: 100svh (small viewport height, always within visible area)."
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
