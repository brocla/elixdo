defmodule ElixdoWeb.Api.ItemControllerTest do
  use ElixdoWeb.ConnCase, async: false

  alias Elixdo.Lists

  # October 2026 dates — safe from collision per test_date_uniqueness_test.exs
  @date ~D[2026-10-10]
  @arrow_target ~D[2026-10-11]

  @token "test-agent-token"

  setup do
    System.put_env("AGENT_TOKEN", @token)
    on_exit(fn -> System.delete_env("AGENT_TOKEN") end)
    :ok
  end

  defp auth_conn(conn) do
    put_req_header(conn, "authorization", "Bearer #{@token}")
  end

  defp insert_item(attrs \\ %{}) do
    defaults = %{body: "test item"}
    {:ok, [item]} = Lists.create_items(attrs[:date] || @date, [Map.merge(defaults, attrs)])
    item
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/items/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/items/:id" do
    test "updates item body", %{conn: conn} do
      item = insert_item(%{body: "original"})

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/items/#{item.id}", %{body: "updated"})

      assert %{"data" => result} = json_response(conn, 200)
      assert result["body"] == "updated"
      assert result["id"] == item.id
    end

    test "transitions status from active to completed", %{conn: conn} do
      item = insert_item()

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/items/#{item.id}", %{status: "completed"})

      assert %{"data" => result} = json_response(conn, 200)
      assert result["status"] == "completed"
    end

    test "transitions status from arrowed_out to active (intentionally allowed)", %{conn: conn} do
      # arrowed_out → active is explicitly permitted by the state machine
      # (supports "Remove All Formats" use case on the LiveView side)
      item = insert_item()
      {:ok, original, _copy} = Lists.arrow_item(item, @arrow_target)

      assert original.status == :arrowed_out

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/items/#{original.id}", %{status: "active"})

      assert %{"data" => result} = json_response(conn, 200)
      assert result["status"] == "active"
    end

    test "returns 422 for forbidden transition (completed → wiggled_out)", %{conn: conn} do
      item = insert_item()
      {:ok, completed} = Lists.update_item(item, %{status: :completed})

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/items/#{completed.id}", %{status: "wiggled_out"})

      assert %{"error" => %{"code" => "forbidden_transition"}} = json_response(conn, 422)
    end

    test "returns 404 for non-existent item", %{conn: conn} do
      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/items/999999", %{body: "anything"})

      assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/items/:id/arrow
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/items/:id/arrow" do
    test "arrows an active item to a target date", %{conn: conn} do
      item = insert_item(%{body: "needs arrowing"})

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/#{item.id}/arrow", %{target_date: "2026-10-11"})

      assert %{"data" => result} = json_response(conn, 200)
      assert result["status"] == "arrowed_out"
      assert result["arrowed_to_date"] == "2026-10-11"
    end

    test "returns 422 when item is not active (completed → cannot arrow)", %{conn: conn} do
      item = insert_item()
      {:ok, completed} = Lists.update_item(item, %{status: :completed})

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/#{completed.id}/arrow", %{target_date: "2026-10-11"})

      assert %{"error" => %{"code" => "forbidden_transition"}} = json_response(conn, 422)
    end

    test "returns 422 when item is not active (wiggled_out → cannot arrow)", %{conn: conn} do
      item = insert_item()
      {:ok, wiggled} = Lists.update_item(item, %{status: :wiggled_out})

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/#{wiggled.id}/arrow", %{target_date: "2026-10-11"})

      assert %{"error" => %{"code" => "forbidden_transition"}} = json_response(conn, 422)
    end

    test "returns 422 for invalid target_date", %{conn: conn} do
      item = insert_item()

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/#{item.id}/arrow", %{target_date: "not-a-date"})

      assert %{"error" => %{"code" => "invalid_date"}} = json_response(conn, 422)
    end

    test "returns 422 when target_date is missing", %{conn: conn} do
      item = insert_item()

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/#{item.id}/arrow", %{})

      assert %{"error" => %{"code" => "validation_error"}} = json_response(conn, 422)
    end

    test "returns 404 for non-existent item", %{conn: conn} do
      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/items/999999/arrow", %{target_date: "2026-10-11"})

      assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
    end
  end
end
