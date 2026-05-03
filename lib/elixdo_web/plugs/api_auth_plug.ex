defmodule ElixdoWeb.ApiAuthPlug do
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    expected = System.get_env("AGENT_TOKEN")

    with {:ok, token} <- bearer_token(conn),
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

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
