# MCP Server Implementation Plan

## Overview

Add an embedded MCP (Model Context Protocol) controller that allows an AI like Claude to interact with Elixdo. The app already has a REST API at `/api/v1`, bearer token auth via `AGENT_TOKEN`, and a clean `Lists` context. The MCP controller is a third consumer of that context (alongside the LiveView and REST API) — not new infrastructure.

---

## What was actually built (post-implementation notes)

This document was rewritten after the implementation was complete. The original plan had several gaps that only became apparent during integration testing with Claude Code. The sections below reflect what it actually takes to get a working MCP server.

---

## Step 1 — Add the MCP route in a dedicated scope

The MCP endpoint must NOT share the `:api_auth` pipeline with the other API routes. The reason: the `:api_auth` pipeline uses `plug :accepts, ["json"]`, which causes Phoenix to return **406 Not Acceptable** when Claude Code sends `Accept: text/event-stream` — which it does for every request, as required by the MCP Streamable HTTP transport spec.

The fix is a separate pipeline with no `:accepts` plug, since the MCP controller handles its own content negotiation:

```elixir
# MCP handles its own content negotiation (JSON and SSE), so no :accepts plug here
pipeline :mcp_auth do
  plug ElixdoWeb.ApiAuthPlug
end

scope "/api/v1", ElixdoWeb.Api do
  pipe_through :api_auth
  # ... existing routes ...
end

scope "/api/v1", ElixdoWeb.Api do
  pipe_through :mcp_auth
  post "/mcp", McpController, :handle
end
```

**Do not** try to add `"event-stream"` to the accepts list — `text/event-stream` is not registered in Phoenix's MIME registry by default and will not work.

---

## Step 2 — Implement the Streamable HTTP transport

Claude Code uses the **MCP Streamable HTTP transport**, which requires the server to check the `Accept` request header and respond in either plain JSON or SSE format accordingly.

When the client sends `Accept: text/event-stream`, the response must be:
```
Content-Type: text/event-stream
Cache-Control: no-cache

event: message
data: {"jsonrpc":"2.0","id":1,"result":{...}}

```

Note the blank line at the end (`\n\n`) — that terminates the SSE event.

Use a private `respond/2` helper in the controller so all clauses stay clean:

```elixir
defp respond(conn, payload) do
  accept = get_req_header(conn, "accept") |> List.first("")

  if String.contains?(accept, "text/event-stream") do
    data = Jason.encode!(payload)
    conn
    |> put_resp_content_type("text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> send_resp(200, "event: message\ndata: #{data}\n\n")
  else
    json(conn, payload)
  end
end
```

Call `respond/2` instead of `json/2` in every handler clause.

---

## Step 3 — Handle JSON-RPC notifications (no `id` field)

After `initialize`, Claude Code sends a `notifications/initialized` notification. JSON-RPC notifications have no `id` field. If your catch-all handler pattern-matches on `%{"id" => id}`, it will not match and Phoenix will return **400 Bad Request**, breaking the handshake.

Add a final catch-all that returns **204 No Content** for all notifications:

```elixir
# JSON-RPC notifications have no "id" — acknowledge with 204, no body.
def handle(conn, _params) do
  send_resp(conn, 204, "")
end
```

This must be the last `handle/2` clause. The MCP handshake will fail silently without it.

---

## Step 4 — Implement the JSON-RPC 2.0 dispatch

The controller handles four cases: `initialize`, `tools/list`, `tools/call`, and the unknown-method fallback (before the notification catch-all):

```elixir
def handle(conn, %{"method" => "initialize", "id" => id}) do
  respond(conn, %{
    jsonrpc: "2.0", id: id,
    result: %{
      protocolVersion: "2024-11-05",
      serverInfo: %{name: "elixdo", version: "1.0"},
      capabilities: %{tools: %{}}
    }
  })
end

def handle(conn, %{"method" => "tools/list", "id" => id}) do
  respond(conn, %{jsonrpc: "2.0", id: id, result: %{tools: tool_definitions()}})
end

def handle(conn, %{"method" => "tools/call", "id" => id,
                   "params" => %{"name" => name, "arguments" => args}}) do
  result = dispatch(name, args)
  respond(conn, %{
    jsonrpc: "2.0", id: id,
    result: %{content: [%{type: "text", text: Jason.encode!(result)}]}
  })
end

def handle(conn, %{"id" => id}) do
  respond(conn, %{jsonrpc: "2.0", id: id,
    error: %{code: -32601, message: "Method not found"}})
end

# Must be last — notifications have no "id"
def handle(conn, _params) do
  send_resp(conn, 204, "")
end
```

---

## Step 5 — Implement the tool dispatcher

The `dispatch/2` function maps tool names to `Lists` context calls. Key notes:

- **Emoji shortcode conversion**: `add_item` and `update_item` must call `Emoji.convert/1` on the body before storing — exactly as the LiveView handlers do. If you skip this, shortcodes like `:fire:` are stored as literal text.
- **`update_item` body is optional**: use a private helper to only convert body when the key is present:
  ```elixir
  defp convert_body(%{"body" => body} = attrs), do: Map.put(attrs, "body", Emoji.convert(body))
  defp convert_body(attrs), do: attrs
  ```
- **`search_items`**: `SearchIndex.search/1` returns `{id, date, body}` tuples, not `ListItem` structs. Serialize manually — do NOT pass to `ItemJSON.item/1`.
- **`arrow_item`**: use `DateHelper.resolve/1` (not `Date.from_iso8601/1`) so relative strings like `"tomorrow"` work.

### Tools exposed

| Tool | Maps to | Notes |
|---|---|---|
| `get_today` | `Clock.today()` | Returns `%{today: "2026-05-04"}` |
| `list_items` | `Lists.get_items_for_date(date)` | |
| `list_items_range` | `Lists.get_items_for_range(from, to, statuses)` | `statuses` is optional; map strings to atoms |
| `add_item` | `Lists.create_items(date, [%{body: body}])` | Apply `Emoji.convert/1` first |
| `update_item` | `Repo.get` + `Lists.update_item(item, attrs)` | Apply `Emoji.convert/1` to body if present |
| `arrow_item` | `Repo.get` + `Lists.arrow_item(item, to_date)` | Use `DateHelper.resolve/1` for target date |
| `search_items` | `SearchIndex.search(query)` | Returns tuples — serialize manually |

---

## Step 6 — Register the server with Claude Code CLI

**The `mcpServers` key in `~/.claude/settings.json` is ignored by Claude Code.** That file controls permissions and hooks only. MCP servers must be registered using the CLI command, which writes to `~/.claude.json`:

```sh
claude mcp add --transport http --scope user elixdo \
  https://yourapp.fly.dev/api/v1/mcp \
  --header "Authorization: Bearer <AGENT_TOKEN>"
```

Verify with:
```sh
claude mcp list
```

You should see `elixdo: ... (HTTP) - ✓ Connected`. If you see `✗ Failed to connect`, run through the troubleshooting section below.

After registering, **start a new Claude Code session**. MCP servers are connected at session startup. Existing sessions will not see the new tools.

---

## Step 7 — Set the `AGENT_TOKEN` on Fly.io

```sh
fly secrets set AGENT_TOKEN=<a long random string>
```

The token gates the `/api/v1/mcp` route via the existing `ApiAuthPlug`. Verify it is set:

```sh
fly secrets list --app <appname>
```

---

## Files changed

| File | Action |
|---|---|
| `lib/elixdo_web/router.ex` | Add `:mcp_auth` pipeline and separate MCP scope |
| `lib/elixdo_web/controllers/api/mcp_controller.ex` | Create (~160 lines) |

---

## Troubleshooting: `✗ Failed to connect`

Work through these in order:

**1. Test the initialize handshake directly:**
```sh
curl -X POST https://yourapp.fly.dev/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```
Should return 200 with `protocolVersion`. If 401, the token is wrong. If 404, the route isn't deployed.

**2. Test SSE response:**
```sh
curl -X POST https://yourapp.fly.dev/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -H "Authorization: Bearer <token>" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```
Should return `event: message\ndata: {...}`. If 406, Phoenix is rejecting `text/event-stream` — the MCP pipeline is using `plug :accepts`.

**3. Test notification handling:**
```sh
curl -X POST https://yourapp.fly.dev/api/v1/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
```
Should return 204. If 400, the notification catch-all handler is missing.

**4. Check tools actually load in a new session:**
```sh
claude mcp list
```
If `✓ Connected` but tools still don't appear as `mcp__elixdo__*` in a session, restart the session — tools are loaded at startup only.

---

## Test plan

Write these tests before implementing. All should be red until the implementation is complete.

**Core protocol:**
1. `initialize returns correct protocol version and capabilities`
2. `tools/list returns all seven tool definitions with required fields`
3. `notifications return 204 with empty body` ← easy to miss, critical for handshake
4. `unknown method returns -32601 error`
5. `missing auth returns 401`
6. `responds with SSE format when Accept: text/event-stream` ← tests the transport layer

**Tool behaviour:**
7. `get_today returns today's date`
8. `list_items returns items for a date`
9. `list_items_range returns items across a date range`
10. `list_items_range with status filter returns only matching items`
11. `add_item creates item and it appears in list_items`
12. `add_item converts shortcodes in body`
13. `update_item changes item body`
14. `update_item converts shortcodes in body`
15. `update_item without body field is unaffected by shortcode conversion`
16. `arrow_item marks original arrowed_out and creates copy on target date`
17. `search_items returns matching results`
