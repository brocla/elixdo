defmodule ElixdoWeb.ApiAuthPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected = System.get_env("AGENT_TOKEN")

    with {"bearer " <> token, _} <- {get_req_header(conn, "authorization") |> List.first("") |> String.downcase(), nil},
         true <- expected != nil and token == expected do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: %{code: "unauthorized", message: "Invalid or missing token"}}))
        |> halt()
    end
  end
end
