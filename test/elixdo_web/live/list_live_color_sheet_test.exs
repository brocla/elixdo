defmodule ElixdoWeb.ListLiveColorSheetTest do
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

  test "last_color defaults to blue at mount", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    assert view |> element(".color-mobile-btn.swatch-blue") |> has_element?()
  end

  test "open_color_sheet sets color_sheet_open: true", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_color_sheet']") |> render_click()
    assert render(view) =~ "bottom-sheet"
  end

  test "close_color_sheet sets color_sheet_open: false", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_color_sheet']") |> render_click()
    view |> element("[phx-click='close_color_sheet']") |> render_click()
    refute render(view) =~ "bottom-sheet"
  end

  test "set_color applies color to selected items", %{conn: conn} do
    date = ~D[2026-09-08]
    {:ok, [item]} = Elixdo.Lists.create_items(date, [%{body: "colorful"}])

    {:ok, view, _} = live(conn, list_path("2026-09-08"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    view |> element("[phx-click='open_color_sheet']") |> render_click()
    view |> element("[phx-click='set_color'][phx-value-color='red']") |> render_click()

    updated = Elixdo.Lists.get_items_for_date(date) |> hd()
    assert updated.color == :red
  end

  test "set_color closes the sheet", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_color_sheet']") |> render_click()
    render_click(view, "set_color", %{"color" => "green"})
    refute render(view) =~ "bottom-sheet"
  end

  test "set_color updates last_color assign", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    view |> element("[phx-click='open_color_sheet']") |> render_click()
    render_click(view, "set_color", %{"color" => "purple"})
    assert render(view) =~ "color-mobile-btn swatch-purple"
  end
end
