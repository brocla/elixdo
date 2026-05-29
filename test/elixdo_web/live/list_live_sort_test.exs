defmodule ElixdoWeb.ListLiveSortTest do
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

  defp item_bodies_from_html(html) do
    ~r/class="item-text">([^<]+)<\/span>/
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
  end

  defp db_bodies(date) do
    date
    |> Elixdo.Lists.get_items_for_date()
    |> Enum.map(& &1.body)
  end

  defp select_and_complete(view, item_id) do
    view |> element("button.item-select-btn[phx-value-id='#{item_id}']") |> render_click()
    view |> element("button[phx-click='set_status'][phx-value-status='completed']") |> render_click()
    render(view)
  end

  test "completing a middle item moves it after active items", %{conn: conn} do
    date = ~D[2026-09-02]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active one"},
        %{body: "complete me"},
        %{body: "active two"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-02"))
    html = select_and_complete(view, b.id)

    bodies = item_bodies_from_html(html)
    active_pos = Enum.find_index(bodies, &(&1 == "active one"))
    active2_pos = Enum.find_index(bodies, &(&1 == "active two"))
    done_pos = Enum.find_index(bodies, &(&1 == "complete me"))

    assert active_pos < done_pos
    assert active2_pos < done_pos
    _ = {a, c}
  end

  test "sort preserves within-group order", %{conn: conn} do
    date = ~D[2026-09-03]

    {:ok, [_a, b, _c, _d]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active first"},
        %{body: "complete me"},
        %{body: "active second"},
        %{body: "active third"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-03"))
    html = select_and_complete(view, b.id)

    bodies = item_bodies_from_html(html)

    # Active items retain their relative order
    assert Enum.find_index(bodies, &(&1 == "active first")) <
             Enum.find_index(bodies, &(&1 == "active second"))

    assert Enum.find_index(bodies, &(&1 == "active second")) <
             Enum.find_index(bodies, &(&1 == "active third"))

    # Completed item is after all active items
    active_third_pos = Enum.find_index(bodies, &(&1 == "active third"))
    done_pos = Enum.find_index(bodies, &(&1 == "complete me"))
    assert active_third_pos < done_pos
  end

  test "completing an already-last item is a no-op on order", %{conn: conn} do
    date = ~D[2026-09-04]

    {:ok, [_a, _b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "alpha"},
        %{body: "beta"},
        %{body: "gamma"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-04"))
    html = select_and_complete(view, c.id)

    assert item_bodies_from_html(html) == ["alpha", "beta", "gamma"]
  end

  test "completing all items preserves their order", %{conn: conn} do
    date = ~D[2026-09-05]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "first"},
        %{body: "second"},
        %{body: "third"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(a, %{status: :completed})
    {:ok, _} = Elixdo.Lists.update_item(b, %{status: :completed})

    # Complete the last remaining active item
    {:ok, view, _} = live(conn, list_path("2026-09-05"))
    html = select_and_complete(view, c.id)

    assert item_bodies_from_html(html) == ["first", "second", "third"]
  end

  test "abandoning an item also sorts it to the bottom", %{conn: conn} do
    date = ~D[2026-09-06]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "keep one"},
        %{body: "abandon me"},
        %{body: "keep two"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-06"))
    view |> element("button.item-select-btn[phx-value-id='#{b.id}']") |> render_click()
    view |> element("button[phx-click='set_status'][phx-value-status='wiggled_out']") |> render_click()
    html = render(view)

    bodies = item_bodies_from_html(html)
    assert Enum.find_index(bodies, &(&1 == "keep one")) <
             Enum.find_index(bodies, &(&1 == "abandon me"))
    assert Enum.find_index(bodies, &(&1 == "keep two")) <
             Enum.find_index(bodies, &(&1 == "abandon me"))
    _ = {a, c}
  end

  test "sort persists to DB", %{conn: conn} do
    date = ~D[2026-09-07]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active"},
        %{body: "complete me"},
        %{body: "active two"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-07"))
    select_and_complete(view, b.id)

    assert db_bodies(date) == ["active", "active two", "complete me"]
    _ = {a, c}
  end
end
