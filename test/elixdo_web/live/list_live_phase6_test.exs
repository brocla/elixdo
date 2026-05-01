defmodule ElixdoWeb.ListLivePhase6Test do
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

  test "reorder event updates item order in LiveView", %{conn: conn} do
    date = ~D[2026-06-01]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "first"}, %{body: "second"}, %{body: "third"}])
    [a, b, c] = items

    {:ok, view, _} = live(conn, list_path("2026-06-01"))

    # Reorder to [c, a, b]
    render_click(view, "reorder", %{"order" => [c.id, a.id, b.id]})

    html = render(view)
    pos_c = :binary.match(html, "third") |> elem(0)
    pos_a = :binary.match(html, "first") |> elem(0)
    pos_b = :binary.match(html, "second") |> elem(0)
    assert pos_c < pos_a
    assert pos_a < pos_b
  end

  test "reorder persists to SQLite after page reload", %{conn: conn} do
    date = ~D[2026-06-02]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "alpha"}, %{body: "beta"}, %{body: "gamma"}])
    [a, b, c] = items

    {:ok, view, _} = live(conn, list_path("2026-06-02"))
    render_click(view, "reorder", %{"order" => [c.id, a.id, b.id]})

    # Reload: new connection, new LiveView
    {:ok, _view2, html2} = live(conn, list_path("2026-06-02"))
    pos_c = :binary.match(html2, "gamma") |> elem(0)
    pos_a = :binary.match(html2, "alpha") |> elem(0)
    assert pos_c < pos_a
  end

  test "reorder broadcasts to second tab via PubSub", %{conn: conn} do
    date = ~D[2026-06-03]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "one"}, %{body: "two"}, %{body: "three"}])
    [a, b, c] = items

    {:ok, view1, _} = live(conn, list_path("2026-06-03"))
    {:ok, _view2, _} = live(conn, list_path("2026-06-03"))

    # Subscribe test process to verify the broadcast is sent
    Phoenix.PubSub.subscribe(Elixdo.PubSub, "list:#{date}")

    render_click(view1, "reorder", %{"order" => [c.id, a.id, b.id]})

    # Verify broadcast was sent with correct order
    assert_receive {:list_updated, ^date, reordered_items}, 1000
    bodies = Enum.map(reordered_items, & &1.body)
    assert bodies == ["three", "one", "two"]
  end

  test "reorder with partial ID list returns error and leaves order unchanged", %{conn: conn} do
    date = ~D[2026-06-04]
    {:ok, items} = Elixdo.Lists.create_items(date, [%{body: "x"}, %{body: "y"}, %{body: "z"}])
    [a, b, _c] = items

    {:ok, view, _} = live(conn, list_path("2026-06-04"))
    # Only send one ID out of three — partial list
    render_click(view, "reorder", %{"order" => [a.id]})

    # Order should be unchanged: x, y, z — check by data-id position
    html = render(view)
    a_marker = "data-id=\"#{a.id}\""
    b_marker = "data-id=\"#{b.id}\""
    pos_x = :binary.match(html, a_marker) |> elem(0)
    pos_y = :binary.match(html, b_marker) |> elem(0)
    assert pos_x < pos_y
  end
end
