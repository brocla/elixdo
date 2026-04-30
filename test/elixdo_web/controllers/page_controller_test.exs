defmodule ElixdoWeb.PageControllerTest do
  use ElixdoWeb.ConnCase

  test "GET /dev-secret/ returns 200", %{conn: conn} do
    conn = get(conn, ~p"/dev-secret/")
    assert html_response(conn, 200) =~ "Elixdo is alive"
  end

  test "GET / without secret returns 404", %{conn: conn} do
    conn = get(conn, "/")
    assert conn.status == 404
  end
end
