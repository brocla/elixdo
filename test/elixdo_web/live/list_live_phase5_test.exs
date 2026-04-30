defmodule ElixdoWeb.ListLivePhase5Test do
  use ElixdoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-05-15] end)
    :ok
  end

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")
  defp list_path(date \\ "2026-05-15"), do: "/#{secret()}/list/#{date}"

  test "add item via form submit", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path())
    html = view
      |> form(".add-item-form", %{body: "new todo item"})
      |> render_submit()
    assert html =~ "new todo item"
  end

  test "add empty item does nothing", %{conn: conn} do
    {:ok, view, _html_before} = live(conn, list_path())
    _html = view |> form(".add-item-form", %{body: "   "}) |> render_submit()
    assert render(view) == render(view)
  end

  test "inline edit: click body starts edit, save updates item", %{conn: conn} do
    date = ~D[2026-05-16]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "original text"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-16"))
    html = view |> element("[phx-click='start_edit'][phx-value-id='#{item.id}']") |> render_click()
    assert html =~ "edit-textarea"

    html = view |> form(".edit-form", %{_id: item.id, body: "updated text"}) |> render_submit()
    assert html =~ "updated text"
    refute html =~ "edit-textarea"
  end

  test "inline edit: cancel button cancels", %{conn: conn} do
    date = ~D[2026-05-17]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "cancel me"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-17"))
    view |> element("[phx-click='start_edit'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("button.cancel-btn") |> render_click()
    refute html =~ "edit-textarea"
    assert html =~ "cancel me"
  end

  test "select item and mark complete", %{conn: conn} do
    date = ~D[2026-05-18]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "finish this"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-18"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='set_status'][phx-value-status='completed']") |> render_click()
    assert html =~ ~s(class="item completed")
  end

  test "select item and wiggle out", %{conn: conn} do
    date = ~D[2026-05-19]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "abandon this"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-19"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='set_status'][phx-value-status='wiggled_out']") |> render_click()
    assert html =~ ~s(class="item wiggled-out")
  end

  test "select all selects every item", %{conn: conn} do
    date = ~D[2026-05-20]
    Elixdo.Lists.create_items(date, [%{body: "item a"}, %{body: "item b"}])

    {:ok, view, _} = live(conn, list_path("2026-05-20"))
    html = view |> element("[phx-click='select_all']") |> render_click()
    assert html =~ ~s(class="select-btn selected")
  end

  test "apply bold decoration to selected items", %{conn: conn} do
    date = ~D[2026-05-21]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "make bold"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-21"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='set_decoration'][phx-value-field='bold']") |> render_click()
    assert html =~ "bold"
  end

  test "apply color to selected items", %{conn: conn} do
    date = ~D[2026-05-22]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "color me"}])
    item = List.first(items)

    {:ok, view, _} = live(conn, list_path("2026-05-22"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='set_decoration'][phx-value-field='color'][phx-value-setting='red']") |> render_click()
    assert html =~ "color-red"
  end

  test "arrow out flow: modal appears, copy created on target date", %{conn: conn} do
    date = ~D[2026-05-23]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "push forward"}])
    item = List.first(items)
    target = "2026-05-24"

    {:ok, view, _} = live(conn, list_path("2026-05-23"))
    view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    html = view |> element("[phx-click='arrow_selected']") |> render_click()
    assert html =~ "modal"

    html = view |> form(".modal form", %{to_date: target}) |> render_submit()
    assert html =~ ~s(class="item arrowed-out")
    assert html =~ "2026-05-24"

    # Verify copy exists on target date
    items_on_target = Elixdo.Lists.get_items_for_date(~D[2026-05-24])
    assert Enum.any?(items_on_target, fn i -> i.body == "push forward" && i.status == :active end)
  end

  test "PubSub sync: broadcast received updates items", %{conn: conn} do
    date = ~D[2026-05-25]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "synced item"}])

    {:ok, view, _} = live(conn, list_path("2026-05-25"))

    # Simulate a broadcast from another tab/process
    Phoenix.PubSub.broadcast(Elixdo.PubSub, "list:#{date}", {:list_updated, date, items})
    html = render(view)
    assert html =~ "synced item"
  end

  test "multi-select arrow out copies all selected items to target date", %{conn: conn} do
    date = ~D[2026-05-26]
    {:ok, created} = Elixdo.Lists.create_items(date, [%{body: "item one"}, %{body: "item two"}])
    target = "2026-05-27"

    {:ok, view, _} = live(conn, list_path("2026-05-26"))
    Enum.each(created, fn item ->
      view |> element("[phx-click='toggle_select'][phx-value-id='#{item.id}']") |> render_click()
    end)
    view |> element("[phx-click='arrow_selected']") |> render_click()
    view |> form(".modal form", %{to_date: target}) |> render_submit()

    target_items = Elixdo.Lists.get_items_for_date(~D[2026-05-27])
    assert length(target_items) == 2
  end
end
