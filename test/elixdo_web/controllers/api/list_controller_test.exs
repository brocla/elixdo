defmodule ElixdoWeb.Api.ListControllerTest do
  use ElixdoWeb.ConnCase, async: false

  alias Elixdo.Lists

  # October 2026 dates — safe from collision per test_date_uniqueness_test.exs
  @date_show ~D[2026-10-01]
  @date_range1 ~D[2026-10-02]
  @date_range2 ~D[2026-10-03]
  @date_status ~D[2026-10-04]
  @date_create ~D[2026-10-05]
  @date_reorder ~D[2026-10-06]

  @token "test-agent-token"

  setup do
    System.put_env("AGENT_TOKEN", @token)
    on_exit(fn -> System.delete_env("AGENT_TOKEN") end)
    :ok
  end

  defp auth_conn(conn) do
    put_req_header(conn, "authorization", "Bearer #{@token}")
  end

  defp insert_items(date, items_attrs) do
    {:ok, items} = Lists.create_items(date, items_attrs)
    items
  end

  # ---------------------------------------------------------------------------
  # Auth
  # ---------------------------------------------------------------------------

  describe "auth" do
    test "returns 401 with no authorization header", %{conn: conn} do
      conn = get(conn, "/api/v1/lists/2026-10-01")
      assert conn.status == 401
      body = json_response(conn, 401)
      assert body["error"]["code"] == "unauthorized"
      assert body["error"]["message"] != nil
    end

    test "returns 401 with wrong token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer wrong-token")
        |> get("/api/v1/lists/2026-10-01")

      assert conn.status == 401
    end

    test "returns 401 with missing Bearer prefix", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", @token)
        |> get("/api/v1/lists/2026-10-01")

      assert conn.status == 401
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/lists/:date
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/lists/:date" do
    test "returns empty list when no items", %{conn: conn} do
      conn = conn |> auth_conn() |> get("/api/v1/lists/2026-10-01")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns items for the date with correct JSON shape", %{conn: conn} do
      [item] = insert_items(@date_show, [%{body: "test item"}])

      conn = conn |> auth_conn() |> get("/api/v1/lists/#{Date.to_iso8601(@date_show)}")
      assert %{"data" => [result]} = json_response(conn, 200)

      assert result["id"] == item.id
      assert result["date"] == "2026-10-01"
      assert result["body"] == "test item"
      assert result["status"] == "active"
      assert result["position"] == 1
      assert result["color"] == nil
      assert result["arrowed_to_date"] == nil
      assert String.ends_with?(result["inserted_at"], "Z")
      assert String.ends_with?(result["updated_at"], "Z")
    end

    test "returns 422 for invalid date", %{conn: conn} do
      conn = conn |> auth_conn() |> get("/api/v1/lists/not-a-date")
      assert %{"error" => %{"code" => "invalid_date"}} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/lists?from=&to=&status=
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/lists (date range query)" do
    test "returns items in range", %{conn: conn} do
      insert_items(@date_range1, [%{body: "day 2 item"}])
      insert_items(@date_range2, [%{body: "day 3 item"}])

      conn =
        conn
        |> auth_conn()
        |> get("/api/v1/lists?from=2026-10-02&to=2026-10-03")

      assert %{"data" => items} = json_response(conn, 200)
      assert length(items) == 2
      bodies = Enum.map(items, & &1["body"])
      assert "day 2 item" in bodies
      assert "day 3 item" in bodies
    end

    test "filters by status param", %{conn: conn} do
      [item] = insert_items(@date_status, [%{body: "will complete"}])
      Lists.update_item(item, %{status: :completed})
      insert_items(@date_status, [%{body: "stays active"}])

      conn =
        conn
        |> auth_conn()
        |> get("/api/v1/lists?from=2026-10-04&to=2026-10-04&status=active")

      assert %{"data" => items} = json_response(conn, 200)
      assert length(items) == 1
      assert hd(items)["body"] == "stays active"
      assert hd(items)["status"] == "active"
    end

    test "returns 422 for invalid from date", %{conn: conn} do
      conn =
        conn
        |> auth_conn()
        |> get("/api/v1/lists?from=bad&to=2026-10-02")

      assert %{"error" => %{"code" => "invalid_date"}} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/lists/:date/items
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/lists/:date/items" do
    test "creates items in bulk and returns 201", %{conn: conn} do
      params = %{items: [%{body: "item one"}, %{body: "item two"}]}

      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/lists/#{Date.to_iso8601(@date_create)}/items", params)

      assert %{"data" => items} = json_response(conn, 201)
      assert length(items) == 2
      assert Enum.map(items, & &1["body"]) == ["item one", "item two"]
    end

    test "returns 422 for invalid date", %{conn: conn} do
      conn =
        conn
        |> auth_conn()
        |> post("/api/v1/lists/bad-date/items", %{items: [%{body: "x"}]})

      assert %{"error" => %{"code" => "invalid_date"}} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/lists/:date/reorder
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/lists/:date/reorder" do
    test "reorders items and returns updated list", %{conn: conn} do
      [i1, i2, i3] = insert_items(@date_reorder, [%{body: "a"}, %{body: "b"}, %{body: "c"}])

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/lists/#{Date.to_iso8601(@date_reorder)}/reorder", %{
          ids: [i3.id, i2.id, i1.id]
        })

      assert %{"data" => items} = json_response(conn, 200)
      assert Enum.map(items, & &1["body"]) == ["c", "b", "a"]
    end

    test "returns 422 for partial reorder (wrong IDs)", %{conn: conn} do
      [i1, _i2] = insert_items(@date_reorder, [%{body: "x"}, %{body: "y"}])

      conn =
        conn
        |> auth_conn()
        |> patch("/api/v1/lists/#{Date.to_iso8601(@date_reorder)}/reorder", %{ids: [i1.id]})

      assert %{"error" => %{"code" => "partial_reorder"}} = json_response(conn, 422)
    end
  end
end
