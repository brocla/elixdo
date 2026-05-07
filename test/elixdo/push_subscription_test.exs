defmodule Elixdo.PushSubscriptionTest do
  use Elixdo.DataCase, async: true

  alias Elixdo.{Repo, PushSubscription}

  @valid_attrs %{
    device_id: "device-abc",
    endpoint: "https://fcm.example.com/push/abc",
    p256dh: "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcx6XeqqgJe3ZhznOPFD5NeolAoNq14_nMcF6YlAjM-qrQ",
    auth: "ozLDPqD5HLnzWG_RIRtyFA"
  }

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset = PushSubscription.changeset(%PushSubscription{}, @valid_attrs)
      assert changeset.valid?
    end

    test "rejects missing device_id" do
      changeset = PushSubscription.changeset(%PushSubscription{}, Map.delete(@valid_attrs, :device_id))
      refute changeset.valid?
      assert %{device_id: [_]} = errors_on(changeset)
    end

    test "rejects missing endpoint" do
      changeset = PushSubscription.changeset(%PushSubscription{}, Map.delete(@valid_attrs, :endpoint))
      refute changeset.valid?
      assert %{endpoint: [_]} = errors_on(changeset)
    end

    test "rejects missing p256dh" do
      changeset = PushSubscription.changeset(%PushSubscription{}, Map.delete(@valid_attrs, :p256dh))
      refute changeset.valid?
      assert %{p256dh: [_]} = errors_on(changeset)
    end

    test "rejects missing auth" do
      changeset = PushSubscription.changeset(%PushSubscription{}, Map.delete(@valid_attrs, :auth))
      refute changeset.valid?
      assert %{auth: [_]} = errors_on(changeset)
    end

    test "rejects duplicate device_id" do
      {:ok, _} = Repo.insert(PushSubscription.changeset(%PushSubscription{}, @valid_attrs))

      duplicate =
        %PushSubscription{}
        |> PushSubscription.changeset(%{@valid_attrs | endpoint: "https://fcm.example.com/push/other"})

      assert {:error, changeset} = Repo.insert(duplicate)
      assert %{device_id: [_]} = errors_on(changeset)
    end

    test "rejects duplicate endpoint" do
      {:ok, _} = Repo.insert(PushSubscription.changeset(%PushSubscription{}, @valid_attrs))

      duplicate =
        %PushSubscription{}
        |> PushSubscription.changeset(%{@valid_attrs | device_id: "other-device"})

      assert {:error, changeset} = Repo.insert(duplicate)
      assert %{endpoint: [_]} = errors_on(changeset)
    end
  end
end
