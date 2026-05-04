# MCP Server Implementation Plan

## Overview

Add an embedded MCP (Model Context Protocol) controller that allows an AI like Claude to interact with Elixdo. The app already has a REST API at `/api/v1`, bearer token auth via `AGENT_TOKEN`, and a clean `Lists` context. The MCP controller is a third consumer of that context (alongside the LiveView and REST API) — not new infrastructure.

---

## Step 1 — Add the MCP route

In `lib/elixdo_web/router.ex`, add one line inside the existing `api_auth` scope:

```elixir
scope "/api/v1", ElixdoWeb.Api do
  pipe_through :api_auth

  # ... existing routes ...
  post "/mcp", McpController, :handle   # ← add this
end
```

The MCP endpoint reuses the same `ApiAuthPlug` and `AGENT_TOKEN` already in place. No new auth work needed.

---

## Step 2 — Create `mcp_controller.ex`

Create `lib/elixdo_web/controllers/api/mcp_controller.ex`. It handles JSON-RPC 2.0 dispatch:

```elixir
defmodule ElixdoWeb.Api.McpController do
  use ElixdoWeb, :controller
  alias Elixdo.{Lists, SearchIndex, Clock, DateHelper}

  def handle(conn, %{"method" => "initialize", "id" => id}) do
    json(conn, %{
      jsonrpc: "2.0", id: id,
      result: %{
        protocolVersion: "2024-11-05",
        serverInfo: %{name: "elixdo", version: "1.0"},
        capabilities: %{tools: %{}}
      }
    })
  end

  def handle(conn, %{"method" => "tools/list", "id" => id}) do
    json(conn, %{jsonrpc: "2.0", id: id, result: %{tools: tool_definitions()}})
  end

  def handle(conn, %{"method" => "tools/call", "id" => id,
                     "params" => %{"name" => name, "arguments" => args}}) do
    result = dispatch(name, args)
    json(conn, %{jsonrpc: "2.0", id: id, result: %{content: [%{type: "text", text: Jason.encode!(result)}]}})
  end

  def handle(conn, %{"id" => id}) do
    json(conn, %{jsonrpc: "2.0", id: id,
      error: %{code: -32601, message: "Method not found"}})
  end
end
```

---

## Step 3 — Implement the tool dispatcher

Still in `mcp_controller.ex`, add a private `dispatch/2` that maps tool names to `Lists` calls.

### Tools to expose

| Tool name | Maps to | Purpose |
|---|---|---|
| `get_today` | `Clock.today()` | AI needs to know the current date for relative operations |
| `list_items` | `Lists.get_items_for_date(date)` | Get items for a specific date |
| `list_items_range` | `Lists.get_items_for_range(from, to, statuses)` | Get items across a date range, optionally filtered by status |
| `add_item` | `Lists.create_items(date, [%{body: body}])` | Add a new item |
| `update_item` | `Repo.get(ListItem, id)` + `Lists.update_item(item, attrs)` | Edit body, status, color, bold, italic, highlighted, prefix |
| `arrow_item` | `Repo.get` + `Lists.arrow_item(item, to_date)` | Move item forward to another date |
| `search_items` | `SearchIndex.search(query)` | Full-text search across all items |

Note: `update_item` and `arrow_item` need a `Repo.get` first — identical to what `ItemController` already does. Extract that into a shared private function or a helper in the `Lists` context.

---

## Step 4 — Define tool schemas

The `tool_definitions()` function returns JSON Schema for each tool so the AI knows what arguments to pass. Example for `list_items`:

```elixir
%{
  name: "list_items",
  description: "Get all items for a specific date",
  inputSchema: %{
    type: "object",
    properties: %{
      date: %{type: "string", description: "ISO 8601 date, e.g. 2026-05-04"}
    },
    required: ["date"]
  }
}
```

Write one schema for each of the seven tools. The descriptions matter — they are how the AI decides which tool to call.

---

## Step 5 — Set the `AGENT_TOKEN` environment variable

The token already gates the `/api/v1` routes. On Fly.io:

```sh
fly secrets set AGENT_TOKEN=<a long random string>
```

Locally, add to `.env` or `config/dev.secret.exs`. The MCP client sends this as `Authorization: Bearer <token>`.

---

## Step 6 — Configure Claude to use the MCP server

### Claude Code CLI

Add to `~/.claude/settings.json` (or the project-level `.claude/settings.json`):

```json
{
  "mcpServers": {
    "elixdo": {
      "type": "http",
      "url": "https://yourapp.fly.dev/api/v1/mcp",
      "headers": {
        "Authorization": "Bearer <AGENT_TOKEN>"
      }
    }
  }
}
```

### Claude.ai web app

Go to Settings → Integrations → Add MCP server. Set the URL to `https://yourapp.fly.dev/api/v1/mcp` and add the bearer token in the headers field.

After connecting, Claude will call `tools/list` automatically and discover the available tools. You can then say things like "add 'buy milk' to today's list" or "show me everything I marked complete last week."

---

## What's not needed

- No new authentication — `AGENT_TOKEN` already exists
- No new context functions — `Lists` already exposes everything needed
- No streaming/SSE — all operations are synchronous, plain JSON responses are sufficient
- No second process or deployment — this lives in the existing Phoenix app

---

## Files to change

| File | Action |
|---|---|
| `lib/elixdo_web/router.ex` | Add 1 line |
| `lib/elixdo_web/controllers/api/mcp_controller.ex` | Create (~120 lines) |
