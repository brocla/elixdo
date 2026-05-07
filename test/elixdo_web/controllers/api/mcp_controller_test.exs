defmodule ElixdoWeb.Api.McpControllerTest do
  use ElixdoWeb.ConnCase, async: false
  import Mox

  alias Elixdo.Lists

  setup :verify_on_exit!

  # November 2026 dates — safe from collision per test_date_uniqueness_test.exs
  @date ~D[2026-11-10]
  @arrow_target ~D[2026-11-11]

  @token "test-agent-token"

  setup do
    Mox.stub(Elixdo.Clock.Mock, :today, fn -> ~D[2026-11-01] end)
    System.put_env("AGENT_TOKEN", @token)
    on_exit(fn -> System.delete_env("AGENT_TOKEN") end)
    :ok
  end

  defp auth_conn(conn) do
    conn
    |> put_req_header("authorization", "Bearer #{@token}")
    |> put_req_header("content-type", "application/json")
  end

  defp mcp(conn, method, params \\ %{}, id \\ 1) do
    body = Jason.encode!(%{jsonrpc: "2.0", id: id, method: method, params: params})
    conn |> auth_conn() |> post("/api/v1/mcp", body)
  end

  defp insert_item(attrs) do
    attrs = Enum.into(attrs, %{})
    {:ok, [item]} = Lists.create_items(attrs[:date] || @date, [Map.merge(%{body: "test item"}, attrs)])
    item
  end


  # ---------------------------------------------------------------------------
  # initialize
  # ---------------------------------------------------------------------------

  test "initialize returns correct protocol version and capabilities", %{conn: conn} do
    resp = mcp(conn, "initialize") |> json_response(200)
    assert resp["jsonrpc"] == "2.0"
    assert resp["result"]["protocolVersion"] == "2024-11-05"
    assert resp["result"]["serverInfo"]["name"] == "elixdo"
    assert is_map(resp["result"]["capabilities"]["tools"])
  end

  # ---------------------------------------------------------------------------
  # tools/list
  # ---------------------------------------------------------------------------

  test "tools/list returns all seven tool definitions with required fields", %{conn: conn} do
    resp = mcp(conn, "tools/list") |> json_response(200)
    tools = resp["result"]["tools"]
    names = Enum.map(tools, & &1["name"]) |> MapSet.new()

    assert MapSet.size(names) == 7
    expected = ~w[get_today list_items list_items_range add_item update_item arrow_item search_items]
    for name <- expected, do: assert(MapSet.member?(names, name), "missing tool: #{name}")

    for tool <- tools do
      assert is_binary(tool["name"])
      assert is_binary(tool["description"])
      assert is_map(tool["inputSchema"])
    end
  end

  # ---------------------------------------------------------------------------
  # tools/call — get_today
  # ---------------------------------------------------------------------------

  test "get_today returns today's date", %{conn: conn} do
    resp = mcp(conn, "tools/call", %{"name" => "get_today", "arguments" => %{}}) |> json_response(200)
    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    result = Jason.decode!(text)
    assert result["today"] =~ ~r/^\d{4}-\d{2}-\d{2}$/
  end

  # ---------------------------------------------------------------------------
  # tools/call — list_items
  # ---------------------------------------------------------------------------

  test "list_items returns items for a date", %{conn: conn} do
    item = insert_item(date: @date, body: "mcp test item")

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items",
        "arguments" => %{"date" => Date.to_iso8601(@date)}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    assert Enum.any?(items, &(&1["id"] == item.id))
  end

  # ---------------------------------------------------------------------------
  # tools/call — add_item
  # ---------------------------------------------------------------------------

  test "add_item creates item and it appears in list_items", %{conn: conn} do
    date_str = "2026-11-12"

    mcp(conn, "tools/call", %{
      "name" => "add_item",
      "arguments" => %{"date" => date_str, "body" => "added via mcp"}
    })
    |> json_response(200)

    items = Lists.get_items_for_date(~D[2026-11-12])
    assert Enum.any?(items, &(&1.body == "added via mcp"))
  end

  # ---------------------------------------------------------------------------
  # tools/call — update_item
  # ---------------------------------------------------------------------------

  test "update_item changes item body", %{conn: conn} do
    item = insert_item(date: @date)

    mcp(conn, "tools/call", %{
      "name" => "update_item",
      "arguments" => %{"id" => item.id, "body" => "updated via mcp"}
    })
    |> json_response(200)

    [updated] = Lists.get_items_for_date(@date) |> Enum.filter(&(&1.id == item.id))
    assert updated.body == "updated via mcp"
  end

  # ---------------------------------------------------------------------------
  # tools/call — arrow_item
  # ---------------------------------------------------------------------------

  test "arrow_item marks original arrowed_out and creates copy on target date", %{conn: conn} do
    item = insert_item(date: @date)

    mcp(conn, "tools/call", %{
      "name" => "arrow_item",
      "arguments" => %{"id" => item.id, "target_date" => Date.to_iso8601(@arrow_target)}
    })
    |> json_response(200)

    original = Lists.get_items_for_date(@date) |> hd()
    assert original.status == :arrowed_out

    copies = Lists.get_items_for_date(@arrow_target)
    assert Enum.any?(copies, &(&1.body == item.body))
  end

  # ---------------------------------------------------------------------------
  # tools/call — search_items
  # ---------------------------------------------------------------------------

  test "search_items returns matching results", %{conn: conn} do
    insert_item(date: @date, body: "uniquesearchterm2026")
    # Give search index time to index
    Process.sleep(50)

    resp =
      mcp(conn, "tools/call", %{
        "name" => "search_items",
        "arguments" => %{"query" => "uniquesearchterm2026"}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    results = Jason.decode!(text)
    assert Enum.any?(results, &(&1["body"] =~ "uniquesearchterm2026"))
  end

  # ---------------------------------------------------------------------------
  # Emoji shortcode conversion
  # ---------------------------------------------------------------------------

  test "add_item converts shortcodes in body", %{conn: conn} do
    mcp(conn, "tools/call", %{
      "name" => "add_item",
      "arguments" => %{"date" => "2026-11-13", "body" => "buy :star: and :rocket:"}
    })
    |> json_response(200)

    [item] = Lists.get_items_for_date(~D[2026-11-13])
    assert item.body == "buy ⭐ and 🚀"
  end

  test "update_item converts shortcodes in body", %{conn: conn} do
    item = insert_item(date: @date, body: "plain text")

    mcp(conn, "tools/call", %{
      "name" => "update_item",
      "arguments" => %{"id" => item.id, "body" => "on :fire: today"}
    })
    |> json_response(200)

    [updated] = Lists.get_items_for_date(@date) |> Enum.filter(&(&1.id == item.id))
    assert updated.body == "on 🔥 today"
  end

  test "update_item without body field is unaffected by shortcode conversion", %{conn: conn} do
    item = insert_item(date: @date, body: "no change")

    mcp(conn, "tools/call", %{
      "name" => "update_item",
      "arguments" => %{"id" => item.id, "status" => "completed"}
    })
    |> json_response(200)

    [updated] = Lists.get_items_for_date(@date) |> Enum.filter(&(&1.id == item.id))
    assert updated.body == "no change"
    assert updated.status == :completed
  end

  # ---------------------------------------------------------------------------
  # list_items_range
  # ---------------------------------------------------------------------------

  test "list_items_range returns items across a date range", %{conn: conn} do
    insert_item(date: ~D[2026-11-14], body: "day one")
    insert_item(date: ~D[2026-11-15], body: "day two")
    insert_item(date: ~D[2026-11-16], body: "outside range")

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items_range",
        "arguments" => %{"from" => "2026-11-14", "to" => "2026-11-15"}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    bodies = Enum.map(items, & &1["body"])
    assert "day one" in bodies
    assert "day two" in bodies
    refute "outside range" in bodies
  end

  test "list_items_range with status filter returns only matching items", %{conn: conn} do
    {:ok, [active]} = Lists.create_items(~D[2026-11-17], [%{body: "still active"}])
    {:ok, [done]} = Lists.create_items(~D[2026-11-17], [%{body: "all done"}])
    Lists.update_item(done, %{status: :completed})

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items_range",
        "arguments" => %{"from" => "2026-11-17", "to" => "2026-11-17", "statuses" => ["active"]}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    bodies = Enum.map(items, & &1["body"])
    assert "still active" in bodies
    refute "all done" in bodies
    _ = active
  end

  # ---------------------------------------------------------------------------
  # Status terminology translation
  # ---------------------------------------------------------------------------

  test "list_items returns 'abandoned' for wiggled_out items", %{conn: conn} do
    item = insert_item(date: ~D[2026-11-18], body: "gave up")
    Lists.update_item(item, %{status: :wiggled_out})

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items",
        "arguments" => %{"date" => "2026-11-18"}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    assert Enum.any?(items, &(&1["status"] == "abandoned"))
  end

  test "list_items returns 'deferred' for arrowed_out items", %{conn: conn} do
    item = insert_item(date: ~D[2026-11-19], body: "moved forward")
    Lists.arrow_item(item, ~D[2026-11-20])

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items",
        "arguments" => %{"date" => "2026-11-19"}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    assert Enum.any?(items, &(&1["status"] == "deferred"))
  end

  test "update_item with status 'abandoned' stores wiggled_out in DB", %{conn: conn} do
    item = insert_item(date: @date, body: "to abandon")

    mcp(conn, "tools/call", %{
      "name" => "update_item",
      "arguments" => %{"id" => item.id, "status" => "abandoned"}
    })
    |> json_response(200)

    [updated] = Lists.get_items_for_date(@date) |> Enum.filter(&(&1.id == item.id))
    assert updated.status == :wiggled_out
  end

  test "list_items_range filters by 'abandoned' status", %{conn: conn} do
    {:ok, [active]} = Lists.create_items(~D[2026-11-21], [%{body: "still going"}])
    {:ok, [gone]} = Lists.create_items(~D[2026-11-21], [%{body: "gave up on this"}])
    Lists.update_item(gone, %{status: :wiggled_out})

    resp =
      mcp(conn, "tools/call", %{
        "name" => "list_items_range",
        "arguments" => %{"from" => "2026-11-21", "to" => "2026-11-21", "statuses" => ["abandoned"]}
      })
      |> json_response(200)

    text = resp["result"]["content"] |> hd() |> Map.fetch!("text")
    items = Jason.decode!(text)
    bodies = Enum.map(items, & &1["body"])
    assert "gave up on this" in bodies
    refute "still going" in bodies
    _ = active
  end

  # ---------------------------------------------------------------------------
  # SSE (Streamable HTTP) transport
  # ---------------------------------------------------------------------------

  test "responds with SSE format when Accept: text/event-stream", %{conn: conn} do
    body = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "initialize", params: %{}})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "text/event-stream")
      |> post("/api/v1/mcp", body)

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/event-stream"
    assert conn.resp_body =~ "event: message\ndata: "
    payload = conn.resp_body |> String.split("data: ") |> List.last() |> String.trim()
    decoded = Jason.decode!(payload)
    assert decoded["result"]["protocolVersion"] == "2024-11-05"
  end

  # ---------------------------------------------------------------------------
  # Notifications
  # ---------------------------------------------------------------------------

  test "notifications (no id) return 204 with empty body", %{conn: conn} do
    body = Jason.encode!(%{jsonrpc: "2.0", method: "notifications/initialized", params: %{}})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@token}")
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/mcp", body)

    assert conn.status == 204
    assert conn.resp_body == ""
  end

  # ---------------------------------------------------------------------------
  # Error cases
  # ---------------------------------------------------------------------------

  test "unknown method returns -32601 error", %{conn: conn} do
    resp = mcp(conn, "not_a_real_method") |> json_response(200)
    assert resp["error"]["code"] == -32601
  end

  test "missing auth returns 401", %{conn: conn} do
    body = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "initialize", params: %{}})
    resp = conn |> put_req_header("content-type", "application/json") |> post("/api/v1/mcp", body) |> json_response(401)
    assert resp["error"]
  end
end
