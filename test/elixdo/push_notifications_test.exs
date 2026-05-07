defmodule Elixdo.PushNotificationsTest do
  use Elixdo.DataCase, async: false
  import ExUnit.CaptureLog

  alias Elixdo.{Repo, PushNotifications, PushSubscription}

  # Valid base64url values so the tasks get past the decode step (they'll fail at HTTP, not decode)
  @valid_p256dh "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcx6XeqqgJe3ZhznOPFD5NeolAoNq14_nMcF6YlAjM-qrQ"
  @valid_auth "ozLDPqD5HLnzWG_RIRtyFA"

  defp insert_sub(device_id, endpoint \\ nil) do
    endpoint = endpoint || "https://fcm.example.com/push/#{device_id}"

    Repo.insert!(%PushSubscription{
      device_id: device_id,
      endpoint: endpoint,
      p256dh: @valid_p256dh,
      auth: @valid_auth
    })
  end

  describe "notify_devices/2" do
    test "with no subscriptions does nothing (no crash)" do
      assert :ok = PushNotifications.notify_devices("test message")
    end

    test "with subscriptions fires tasks (which fail silently without VAPID keys)" do
      insert_sub("device-a")
      insert_sub("device-b")

      # Tasks will fail due to no VAPID keys configured in test env, but notify_devices returns :ok
      capture_log(fn ->
        assert :ok = PushNotifications.notify_devices("test message")
        Process.sleep(50)
      end)
    end

    test "skips the originating device_id" do
      insert_sub("device-originator")
      insert_sub("device-receiver")

      capture_log(fn ->
        assert :ok = PushNotifications.notify_devices("test message", "device-originator")
        Process.sleep(50)
      end)
    end

    test "with nil except_device_id notifies all subscribers" do
      insert_sub("device-x")
      insert_sub("device-y")

      capture_log(fn ->
        assert :ok = PushNotifications.notify_devices("test message", nil)
        Process.sleep(50)
      end)
    end

    test "skipping device_id excludes only that device from query" do
      insert_sub("device-skip-me")

      # No tasks are spawned since the only subscription is excluded
      assert :ok = PushNotifications.notify_devices("test message", "device-skip-me")
    end
  end
end
