defmodule ElixdoWeb.HealthController do
  @moduledoc false
  use ElixdoWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
