defmodule Elixdo.ConfigTest do
  @moduledoc """
  Guards critical configuration values that are easy to accidentally change
  and whose breakage only shows up at deploy time, not during local testing.
  """
  use ExUnit.Case, async: true

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
