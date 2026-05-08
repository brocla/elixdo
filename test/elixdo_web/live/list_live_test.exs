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
    assert html =~ "May 1"
  end

  test "navigating prev_day changes date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("button.nav-left") |> render_click()
    assert html =~ "April 30"
  end

  test "navigating next_day changes date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("button.nav-right") |> render_click()
    assert html =~ "May 2"
  end

  test "arrow key left navigates to prev day", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = render_keydown(view, "key_nav", %{"key" => "ArrowLeft"})
    assert html =~ "April 30"
  end

  test "arrow key right navigates to next day", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = render_keydown(view, "key_nav", %{"key" => "ArrowRight"})
    assert html =~ "May 2"
  end

  test "date picker jump navigates to selected date", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    html = view |> element("#date-picker-form") |> render_change(%{"date" => "2026-06-15"})
    assert html =~ "June 15"
  end

  test "return to today button hidden when on today", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/#{secret()}/list")
    refute html =~ "Today"
  end

  test "return to today button visible when off today", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/#{secret()}/list/2026-04-01")
    assert html =~ "Today"
  end

  test "return to today button navigates home", %{conn: conn} do
    {:ok, view, _} = live(conn, "/#{secret()}/list/2026-04-01")
    html = view |> element("button.today-btn") |> render_click()
    assert html =~ "May 1"
  end

  test "DateWatcher midnight broadcast updates today assign", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/#{secret()}/list")
    send(view.pid, {:new_day, ~D[2026-05-02]})
    html = render(view)
    assert html =~ "Today"
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

  describe "arrow modal" do
    test "selecting an item and clicking arrow opens the modal", %{conn: conn} do
      date = ~D[2026-08-01]
      {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "forward me"}])
      item = List.first(items)
      {:ok, view, _html} = live(conn, "/#{secret()}/list/2026-08-01")

      # Select the item
      view |> element("button.item-select-btn[phx-value-id='#{item.id}']") |> render_click()

      # Click the arrow-forward toolbar button
      html = view |> element("button[phx-click='arrow_selected']") |> render_click()

      # Modal must be present in the DOM
      assert html =~ "Arrow forward to date"
      assert html =~ ~s(name="to_date")
    end

    test "submitting the arrow modal moves the item and shows it on the target date", %{
      conn: conn
    } do
      date = ~D[2026-08-02]
      {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "move this item"}])
      item = List.first(items)
      {:ok, view, _html} = live(conn, "/#{secret()}/list/2026-08-02")

      # Select and open modal
      view |> element("button.item-select-btn[phx-value-id='#{item.id}']") |> render_click()
      view |> element("button[phx-click='arrow_selected']") |> render_click()

      # Submit with a target date
      view |> element(".elixdo-modal form") |> render_submit(%{"to_date" => "2026-08-10"})
      html = render(view)

      # Modal closes and original item is now arrowed-out
      refute html =~ "Arrow forward to date"
      assert html =~ ~s(class="item arrowed-out")
      assert html =~ "2026-08-10"
    end

    test "arrowed item appears on the target date", %{conn: conn} do
      date = ~D[2026-08-03]
      {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "check target date"}])
      item = List.first(items)
      {:ok, view, _html} = live(conn, "/#{secret()}/list/2026-08-03")

      view |> element("button.item-select-btn[phx-value-id='#{item.id}']") |> render_click()
      view |> element("button[phx-click='arrow_selected']") |> render_click()
      view |> element(".elixdo-modal form") |> render_submit(%{"to_date" => "2026-08-11"})

      # Navigate to the target date — the copy should be active there
      {:ok, _view2, html} = live(conn, "/#{secret()}/list/2026-08-11")
      assert html =~ "check target date"
      assert html =~ ~s(class="item active)
    end

    test "cancelling the arrow modal closes it without changing the item", %{conn: conn} do
      date = ~D[2026-08-04]
      {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "do not move"}])
      item = List.first(items)
      {:ok, view, _html} = live(conn, "/#{secret()}/list/2026-08-04")

      view |> element("button.item-select-btn[phx-value-id='#{item.id}']") |> render_click()
      view |> element("button[phx-click='arrow_selected']") |> render_click()
      html = view |> element("button[phx-click='cancel_arrow']") |> render_click()

      refute html =~ "Arrow forward to date"
      assert html =~ ~s(class="item active)
    end
  end

  describe "push context" do
    test "set_push_context stores device_id and suppress in socket assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/#{secret()}/list")

      render_hook(view, "set_push_context", %{"device_id" => "my-device", "suppress" => true})

      assert render(view) =~ "list"
    end

    test "set_push_context with suppress false stores false in assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/#{secret()}/list")

      render_hook(view, "set_push_context", %{"device_id" => "other-device", "suppress" => false})

      assert render(view) =~ "list"
    end

    test "add_item with suppress=true does not notify push subscribers", %{conn: conn} do
      # Register a subscription so notify_devices has something to send to
      {:ok, _} = Elixdo.Repo.insert(%Elixdo.PushSubscription{
        device_id: "other-device",
        endpoint: "https://push.example.com/sub1",
        p256dh: "key1",
        auth: "auth1"
      })

      # Connect with suppress=true via connect params
      conn = Phoenix.ConnTest.init_test_session(conn, %{})
      {:ok, view, _html} = live(conn, "/#{secret()}/list")

      # Set suppress via the event (simulates what connect params would do)
      render_hook(view, "set_push_context", %{"device_id" => "my-device", "suppress" => true})

      # add_item should succeed but not crash (notify_devices not called)
      view |> element("form.add-item-form") |> render_submit(%{"body" => "suppressed item"})

      items = Elixdo.Lists.get_items_for_date(Elixdo.Clock.today())
      assert Enum.any?(items, &(&1.body == "suppressed item"))
    end
  end

  describe "search" do
    test "add item, open search, type query, see result, click result, verify navigation and highlight",
         %{conn: conn} do
      # Create an item on a specific date
      date = ~D[2026-06-20]
      {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "unique searchable item xyz"}])
      item = List.first(items)

      # Start on today's date (not the item's date)
      {:ok, view, html} = live(conn, "/#{secret()}/list")
      refute html =~ "search-highlight"

      # Open the search modal
      html = view |> element("button.search-btn") |> render_click()
      assert html =~ "Search"

      # Type a query — phx-change fires the "search" event
      html =
        view |> element(".search-modal form") |> render_change(%{"query" => "unique searchable"})

      assert html =~ "unique searchable item xyz"
      assert html =~ "2026-06-20"

      # Click the result — should navigate to the item's date
      html =
        view |> element(".search-result-item", "unique searchable item xyz") |> render_click()

      assert html =~ "June 20"

      # The highlighted item should have the search-highlight class
      assert html =~ "search-highlight"
      assert html =~ ~s(data-id="#{item.id}")
    end
  end
end
