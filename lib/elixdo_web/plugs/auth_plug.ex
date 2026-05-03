defmodule ElixdoWeb.AuthPlug do
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug

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
