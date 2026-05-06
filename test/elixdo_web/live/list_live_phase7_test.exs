defmodule ElixdoWeb.ListLivePhase7Test do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-05-01] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")
  defp list_path(date), do: "/#{secret()}/list/#{date}"

  test "voice_input event creates a list item", %{conn: conn} do
    date = ~D[2026-07-01]
    {:ok, view, _} = live(conn, list_path("2026-07-01"))

    render_click(view, "voice_input", %{"text" => "buy milk"})

    items = Elixdo.Lists.get_items_for_date(date)
    assert Enum.any?(items, &(&1.body == "buy milk"))
  end

  test "voice_input with blank text creates no item", %{conn: conn} do
    date = ~D[2026-07-02]
    {:ok, view, _} = live(conn, list_path("2026-07-02"))

    render_click(view, "voice_input", %{"text" => "   "})

    items = Elixdo.Lists.get_items_for_date(date)
    assert items == []
  end

  test "voice_input item appears in the rendered list", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-07-03"))

    render_click(view, "voice_input", %{"text" => "call dentist"})

    html = render(view)
    assert html =~ "call dentist"
  end
end
