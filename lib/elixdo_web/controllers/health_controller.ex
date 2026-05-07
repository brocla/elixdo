defmodule ElixdoWeb.HealthController do
  @moduledoc false
  use ElixdoWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok", sha: System.get_env("GIT_SHA", "unknown")})
  end
end
