defmodule Elixdo.PushNotifications do
  @moduledoc false
  alias Elixdo.{Repo, PushSubscription}
  import Ecto.Query

  def notify_devices(message, except_device_id \\ nil) do
    subscriptions =
      from(s in PushSubscription,
        where: s.device_id != ^(except_device_id || ""))
      |> Repo.all()

    Enum.each(subscriptions, fn sub ->
      payload = Jason.encode!(%{title: "Elixdo", body: message})

      subscription =
        Jason.encode!(%{
          "endpoint" => sub.endpoint,
          "keys" => %{"p256dh" => sub.p256dh, "auth" => sub.auth}
        })

      Task.start(fn -> WebPushElixir.send_notification(subscription, payload) end)
    end)
  end
end
