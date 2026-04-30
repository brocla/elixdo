defmodule ElixdoWeb.ListLiveTest do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-05-01] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")

  test "mounts and shows today's date", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/#{secret()}/list")
    assert html =~ "May 1, 2026"
  end

  test "navigating prev_day changes date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("button.nav-left") |> render_click()
    assert html =~ "April 30, 2026"
  end

  test "navigating next_day changes date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("button.nav-right") |> render_click()
    assert html =~ "May 2, 2026"
  end

  test "arrow key left navigates to prev day", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
    assert html =~ "April 30, 2026"
  end

  test "arrow key right navigates to next day", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = render_keydown(view, "key_nav", %{"key" => "ArrowRight"})
    assert html =~ "May 2, 2026"
  end

  test "date picker jump navigates to selected date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("#date-picker-form") |> render_change(%{"date" => "2026-06-15"})
    assert html =~ "June 15, 2026"
  end

  test "return to today button hidden when on today", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/#{secret()}/list")
    refute html =~ "↩ Today"
  end

  test "return to today button visible when off today", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/#{secret()}/list/2026-04-01")
    assert html =~ "↩ Today"
  end

  test "return to today button navigates home", %{conn: conn} do
    {:ok, view, _} = live(conn, "/#{secret()}/list/2026-04-01")
    html = view |> element("button.today-btn") |> render_click()
    assert html =~ "May 1, 2026"
  end

  test "DateWatcher midnight broadcast updates today assign", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    send(view.pid, {:new_day, ~D[2026-05-02]})
    html = render(view)
    assert html =~ "↩ Today"
  end

  test "completed item renders with completed class", %{conn: conn} do
    date = ~D[2026-05-10]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "done item"}])
    item = List.first(items)
    {:ok, _} = Elixdo.Lists.update_item(item, %{status: :completed})
    {:ok, _view, html} = live(conn, "/#{secret()}/list/2026-05-10")
    assert html =~ ~s(class="item completed")
  end

  test "wiggled_out item renders with wiggled-out class", %{conn: conn} do
    date = ~D[2026-05-11]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "wiggled item"}])
    item = List.first(items)
    {:ok, _} = Elixdo.Lists.update_item(item, %{status: :wiggled_out})
    {:ok, _view, html} = live(conn, "/#{secret()}/list/2026-05-11")
    assert html =~ ~s(class="item wiggled-out")
  end

  test "arrowed_out item renders with arrowed-out class and arrow annotation", %{conn: conn} do
    date = ~D[2026-05-12]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "arrowed item"}])
    item = List.first(items)
    {:ok, _original, _copy} = Elixdo.Lists.arrow_item(item, ~D[2026-05-13])
    {:ok, _view, html} = live(conn, "/#{secret()}/list/2026-05-12")
    assert html =~ ~s(class="item arrowed-out")
    assert html =~ "2026-05-13"
  end
end
