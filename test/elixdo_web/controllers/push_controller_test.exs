defmodule ElixdoWeb.PushControllerTest do
  use ElixdoWeb.ConnCase, async: false

  alias Elixdo.{Repo, PushSubscription}

  defp secret, do: System.get_env("SECRET_PATH", "dev-secret")

  @valid_sub %{
    "device_id" => "test-device-1",
    "endpoint" => "https://fcm.example.com/push/test1",
    "p256dh" => "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcx6XeqqgJe3ZhznOPFD5NeolAoNq14_nMcF6YlAjM-qrQ",
    "auth" => "ozLDPqD5HLnzWG_RIRtyFA"
  }

  describe "POST /:secret/push/subscribe" do
    test "inserts a new subscription", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/#{secret()}/push/subscribe", @valid_sub)

      assert conn.status == 200
      assert Repo.get_by(PushSubscription, device_id: "test-device-1")
    end

    test "upserts on device_id conflict (updates endpoint)", %{conn: conn} do
      # Insert first
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/#{secret()}/push/subscribe", @valid_sub)

      # Update with new endpoint
      updated = %{@valid_sub | "endpoint" => "https://fcm.example.com/push/updated"}

      conn2 =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/#{secret()}/push/subscribe", updated)

      assert conn2.status == 200

      sub = Repo.get_by(PushSubscription, device_id: "test-device-1")
      assert sub.endpoint == "https://fcm.example.com/push/updated"
    end

    test "returns 422 with missing fields", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/#{secret()}/push/subscribe", %{"device_id" => "only-id"})

      assert conn.status == 422
    end

    test "returns 404 with wrong secret", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/wrong-secret/push/subscribe", @valid_sub)

      assert conn.status == 404
    end
  end

  describe "DELETE /:secret/push/subscribe" do
    test "removes the subscription", %{conn: conn} do
      Repo.insert!(PushSubscription.changeset(%PushSubscription{}, %{
        device_id: "test-device-2",
        endpoint: "https://fcm.example.com/push/del",
        p256dh: "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcx6XeqqgJe3ZhznOPFD5NeolAoNq14_nMcF6YlAjM-qrQ",
        auth: "ozLDPqD5HLnzWG_RIRtyFA"
      }))

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/#{secret()}/push/subscribe", %{"device_id" => "test-device-2"})

      assert conn.status == 204
      refute Repo.get_by(PushSubscription, device_id: "test-device-2")
    end

    test "returns 204 for unknown device_id", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/#{secret()}/push/subscribe", %{"device_id" => "nonexistent-device"})

      assert conn.status == 204
    end
  end

  describe "GET /push/vapid-public-key" do
    test "returns the public key", %{conn: conn} do
      Application.put_env(:web_push_elixir, :vapid_public_key, "test_public_key_value")

      conn = get(conn, "/push/vapid-public-key")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["public_key"] == "test_public_key_value"
    end
  end
end
