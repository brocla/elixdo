defmodule Elixdo.DateHelperTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-05-01] end)
    :ok
  end

  test "resolves today" do
    assert {:ok, ~D[2026-05-01]} = Elixdo.DateHelper.resolve("today")
  end

  test "resolves yesterday" do
    assert {:ok, ~D[2026-04-30]} = Elixdo.DateHelper.resolve("yesterday")
  end

  test "resolves tomorrow" do
    assert {:ok, ~D[2026-05-02]} = Elixdo.DateHelper.resolve("tomorrow")
  end

  test "resolves ISO 8601 date string" do
    assert {:ok, ~D[2026-03-15]} = Elixdo.DateHelper.resolve("2026-03-15")
  end

  test "returns error for invalid string" do
    assert {:error, :invalid_date} = Elixdo.DateHelper.resolve("not-a-date")
  end

  test "passes through Date struct unchanged" do
    assert {:ok, ~D[2026-01-01]} = Elixdo.DateHelper.resolve(~D[2026-01-01])
  end

  test "returns error for nil" do
    assert {:error, :invalid_date} = Elixdo.DateHelper.resolve(nil)
  end
end
