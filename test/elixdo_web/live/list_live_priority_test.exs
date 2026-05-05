defmodule ElixdoWeb.ListLivePriorityTest do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-08-15] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")
  defp list_path(date \\ "2026-08-15"), do: "/#{secret()}/list/#{date}"

  test "default drag handle is ⠿ when priority is nil", %{conn: conn} do
    {:ok, _} = Elixdo.Lists.create_items(~D[2026-08-15], [%{body: "plain item"}])
    {:ok, _view, html} = live(conn, list_path())
    assert html =~ "⠿"
  end

  test "set_priority sets priority on selected item and renders it in drag handle", %{conn: conn} do
    date = ~D[2026-08-16]
    {:ok, [item]} = Elixdo.Lists.create_items(date, [%{body: "prioritize me"}])

    {:ok, view, _} = live(conn, list_path("2026-08-16"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='set_priority'][phx-value-priority='🔥']") |> render_click()

    assert html =~ "🔥"
    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.priority == "🔥"
  end

  test "remove_formats clears priority", %{conn: conn} do
    date = ~D[2026-08-17]
    {:ok, [item]} = Elixdo.Lists.create_items(date, [%{body: "has priority"}])
    {:ok, _} = Elixdo.Lists.update_item(item, %{priority: "⭐"})

    {:ok, view, _} = live(conn, list_path("2026-08-17"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    view |> element("[phx-click='remove_formats']") |> render_click()

    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.priority == nil
  end
end
