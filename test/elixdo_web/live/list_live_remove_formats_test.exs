defmodule ElixdoWeb.ListLiveRemoveFormatsTest do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-07-01] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")
  defp list_path(date), do: "/#{secret()}/list/#{date}"

  defp select_item(view, item) do
    view
    |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']")
    |> render_click()
  end

  defp click_remove_formats(view) do
    view |> element("[phx-click='remove_formats']") |> render_click()
    render(view)
  end

  test "remove_formats clears color on an active item", %{conn: conn} do
    date = ~D[2026-07-04]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "colored item"}])
    item = List.first(items)
    {:ok, _} = Elixdo.Lists.update_item(item, %{color: :red})

    {:ok, view, _} = live(conn, list_path("2026-07-04"))
    select_item(view, item)
    html = click_remove_formats(view)

    refute html =~ "color-red"
    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.color == nil
  end

  test "remove_formats clears formatting on a completed item and restores active status", %{
    conn: conn
  } do
    date = ~D[2026-07-05]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "completed formatted"}])
    item = List.first(items)
    {:ok, completed} = Elixdo.Lists.update_item(item, %{status: :completed})
    {:ok, _} = Elixdo.Lists.update_item(completed, %{color: :blue})

    {:ok, view, _} = live(conn, list_path("2026-07-05"))
    select_item(view, item)
    html = click_remove_formats(view)

    assert html =~ ~s(class="item active")
    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.status == :active
    assert db_item.color == nil
  end

  test "remove_formats clears formatting on a wiggled_out item and restores active status", %{
    conn: conn
  } do
    date = ~D[2026-07-06]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "wiggled formatted"}])
    item = List.first(items)
    {:ok, _wiggled} = Elixdo.Lists.update_item(item, %{status: :wiggled_out})

    {:ok, view, _} = live(conn, list_path("2026-07-06"))
    select_item(view, item)
    html = click_remove_formats(view)

    assert html =~ ~s(class="item active")
    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.status == :active
  end

  test "remove_formats on an arrowed_out item restores it to active and clears arrow", %{
    conn: conn
  } do
    date = ~D[2026-07-07]
    target_date = ~D[2026-07-08]

    {:ok, items} =
      Elixdo.Lists.create_items(date, [%{body: "arrowed formatted", color: :green}])

    item = List.first(items)
    {:ok, _original, _copy} = Elixdo.Lists.arrow_item(item, target_date)

    {:ok, view, _} = live(conn, list_path("2026-07-07"))
    arrowed_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert arrowed_item.status == :arrowed_out

    select_item(view, arrowed_item)
    html = click_remove_formats(view)

    # Status must now be active, strikethrough and arrow annotation gone
    assert html =~ ~s(class="item active")
    refute html =~ ~s(class="item arrowed-out")
    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.status == :active
    assert db_item.arrowed_to_date == nil
    assert db_item.color == nil

    # Copy on the target date must be untouched
    copy =
      Elixdo.Lists.get_items_for_date(target_date) |> Enum.find(&(&1.body == "arrowed formatted"))

    assert copy != nil
    assert copy.status == :active
  end

  test "remove_formats clears all format fields simultaneously", %{conn: conn} do
    date = ~D[2026-07-09]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "all formats"}])
    item = List.first(items)

    {:ok, _} = Elixdo.Lists.update_item(item, %{color: :purple})

    {:ok, view, _} = live(conn, list_path("2026-07-09"))
    select_item(view, item)
    click_remove_formats(view)

    db_item = Elixdo.Lists.get_items_for_date(date) |> Enum.find(&(&1.id == item.id))
    assert db_item.color == nil
    assert db_item.status == :active
  end
end
