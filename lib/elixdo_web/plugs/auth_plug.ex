defmodule ElixdoWeb.AuthPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected = System.get_env("SECRET_PATH", "dev-secret")

    # Extract the first path segment
    case conn.path_info do
      [segment | _] when segment == expected ->
        conn

      _ ->
        conn
        |> send_resp(404, "Not found")
        |> halt()
    end
  end
end
