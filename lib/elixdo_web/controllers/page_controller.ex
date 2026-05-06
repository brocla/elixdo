defmodule ElixdoWeb.PageController do
  @moduledoc false
  use ElixdoWeb, :controller

  def index(conn, _params) do
    denver_date =
      DateTime.now!("America/Denver")
      |> DateTime.to_date()

    render(conn, :index, date: denver_date)
  end
end
