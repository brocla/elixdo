defmodule ElixdoWeb.ListLivePrioritySheetTest do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-09-01] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")
  defp list_path(date), do: "/#{secret()}/list/#{date}"

  test "priority_sheet_open defaults to false at mount", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    refute render(view) =~ "priority-sheet-btn"
  end

  test "open_priority_sheet sets priority_sheet_open: true", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_priority_sheet']") |> render_click()
    assert render(view) =~ "priority-sheet-btn"
  end

  test "close_priority_sheet sets priority_sheet_open: false", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_priority_sheet']") |> render_click()
    view |> element("[phx-click='close_priority_sheet']") |> render_click()
    refute render(view) =~ "priority-sheet-btn"
  end

  test "set_priority from the sheet closes the sheet", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_priority_sheet']") |> render_click()
    render_click(view, "set_priority", %{"priority" => "⭐"})
    refute render(view) =~ "priority-sheet-btn"
  end

  test "set_priority from the sheet applies priority to selected items", %{conn: conn} do
    date = ~D[2026-09-09]
    {:ok, [item]} = Elixdo.Lists.create_items(date, [%{body: "important"}])

    {:ok, view, _} = live(conn, list_path("2026-09-09"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    view |> element("[phx-click='open_priority_sheet']") |> render_click()
    render_click(view, "set_priority", %{"priority" => "🔥"})

    updated = Elixdo.Lists.get_items_for_date(date) |> hd()
    assert updated.priority == "🔥"
  end
end
