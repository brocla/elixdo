defmodule Elixdo.PushSender do
  @moduledoc false
  # Behaviour so the real WebPushElixir call can be swapped for a mock in tests.
  @callback send(subscription :: String.t(), payload :: String.t()) :: any()
  def send(subscription, payload), do: impl().send(subscription, payload)
  defp impl, do: Application.get_env(:elixdo, :push_sender, Elixdo.PushSender.Real)
end

defmodule Elixdo.PushSender.Real do
  @moduledoc false
  @behaviour Elixdo.PushSender
  def send(subscription, payload), do: WebPushElixir.send_notification(subscription, payload)
end

defmodule Elixdo.PushNotifications do
  @moduledoc false
  alias Elixdo.{Repo, PushSubscription, PushSender}
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

      Task.start(fn -> PushSender.send(subscription, payload) end)
    end)
  end
end
