defmodule ElixdoWeb.PushController do
  @moduledoc false
  use ElixdoWeb, :controller

  alias Elixdo.{Repo, PushSubscription}

  def subscribe(conn, %{"device_id" => device_id, "endpoint" => endpoint, "p256dh" => p256dh, "auth" => auth}) do
    attrs = %{device_id: device_id, endpoint: endpoint, p256dh: p256dh, auth: auth}

    result =
      case Repo.get_by(PushSubscription, device_id: device_id) do
        nil ->
          %PushSubscription{}
          |> PushSubscription.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> PushSubscription.changeset(attrs)
          |> Repo.update()
      end

    case result do
      {:ok, _sub} ->
        send_resp(conn, 200, "")

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def subscribe(conn, _params) do
    conn
    |> put_status(422)
    |> json(%{errors: %{base: ["missing required fields"]}})
  end

  def unsubscribe(conn, %{"device_id" => device_id}) do
    case Repo.get_by(PushSubscription, device_id: device_id) do
      nil -> :ok
      sub -> Repo.delete(sub)
    end

    send_resp(conn, 204, "")
  end

  def unsubscribe(conn, _params) do
    send_resp(conn, 204, "")
  end

  def vapid_key(conn, _params) do
    public_key = Application.get_env(:web_push_elixir, :vapid_public_key)
    json(conn, %{public_key: public_key})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
