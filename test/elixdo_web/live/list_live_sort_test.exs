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

  defp sort_and_render(view) do
    view |> element("[phx-click='sort_active']") |> render_click()
    render(view)
  end

  test "sort_active moves active items before completed", %{conn: conn} do
    date = ~D[2026-09-02]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active one"},
        %{body: "done"},
        %{body: "active two"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(b, %{status: :completed})

    {:ok, view, _} = live(conn, list_path("2026-09-02"))
    html = sort_and_render(view)

    bodies = item_bodies_from_html(html)
    active_pos = Enum.find_index(bodies, &(&1 == "active one"))
    active2_pos = Enum.find_index(bodies, &(&1 == "active two"))
    done_pos = Enum.find_index(bodies, &(&1 == "done"))

    assert active_pos < done_pos
    assert active2_pos < done_pos
    _ = {a, c}
  end

  test "sort_active preserves within-group order", %{conn: conn} do
    date = ~D[2026-09-03]

    {:ok, [a, b, c, d]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active first"},
        %{body: "completed first"},
        %{body: "active second"},
        %{body: "completed second"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(b, %{status: :completed})
    {:ok, _} = Elixdo.Lists.update_item(d, %{status: :completed})

    {:ok, view, _} = live(conn, list_path("2026-09-03"))
    html = sort_and_render(view)

    bodies = item_bodies_from_html(html)

    assert Enum.find_index(bodies, &(&1 == "active first")) <
             Enum.find_index(bodies, &(&1 == "active second"))

    assert Enum.find_index(bodies, &(&1 == "completed first")) <
             Enum.find_index(bodies, &(&1 == "completed second"))

    _ = {a, c}
  end

  test "sort_active on already-sorted list is a no-op", %{conn: conn} do
    date = ~D[2026-09-04]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "alpha"},
        %{body: "beta"},
        %{body: "done"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(c, %{status: :completed})

    {:ok, view, _} = live(conn, list_path("2026-09-04"))
    html = sort_and_render(view)

    assert item_bodies_from_html(html) == ["alpha", "beta", "done"]
    _ = {a, b}
  end

  test "sort_active on all-active list preserves order", %{conn: conn} do
    date = ~D[2026-09-05]

    {:ok, _} =
      Elixdo.Lists.create_items(date, [
        %{body: "first"},
        %{body: "second"},
        %{body: "third"}
      ])

    {:ok, view, _} = live(conn, list_path("2026-09-05"))
    html = sort_and_render(view)

    assert item_bodies_from_html(html) == ["first", "second", "third"]
  end

  test "sort_active on all-non-active list preserves order", %{conn: conn} do
    date = ~D[2026-09-06]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "done one"},
        %{body: "done two"},
        %{body: "done three"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(a, %{status: :completed})
    {:ok, _} = Elixdo.Lists.update_item(b, %{status: :completed})
    {:ok, _} = Elixdo.Lists.update_item(c, %{status: :completed})

    {:ok, view, _} = live(conn, list_path("2026-09-06"))
    html = sort_and_render(view)

    assert item_bodies_from_html(html) == ["done one", "done two", "done three"]
  end

  test "sort_active persists to DB", %{conn: conn} do
    date = ~D[2026-09-07]

    {:ok, [a, b, c]} =
      Elixdo.Lists.create_items(date, [
        %{body: "active"},
        %{body: "completed"},
        %{body: "active two"}
      ])

    {:ok, _} = Elixdo.Lists.update_item(b, %{status: :completed})

    {:ok, view, _} = live(conn, list_path("2026-09-07"))
    sort_and_render(view)

    assert db_bodies(date) == ["active", "active two", "completed"]
    _ = {a, c}
  end

  test "sort_active on empty list is a no-op", %{conn: conn} do
    {:ok, view, _} = live(conn, list_path("2026-09-01"))
    html = sort_and_render(view)
    assert item_bodies_from_html(html) == []
  end
end
