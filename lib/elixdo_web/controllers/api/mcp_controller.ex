defmodule ElixdoWeb.Api.McpController do
  use ElixdoWeb, :controller

  alias Elixdo.{Lists, SearchIndex, Clock, DateHelper, Repo, ListItem, Emoji}
  alias ElixdoWeb.Api.ItemJSON

  # ---------------------------------------------------------------------------
  # JSON-RPC 2.0 dispatch
  # ---------------------------------------------------------------------------

  def handle(conn, %{"method" => "initialize", "id" => id}) do
    respond(conn, %{
      jsonrpc: "2.0",
      id: id,
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

  def handle(conn, %{
        "method" => "tools/call",
        "id" => id,
        "params" => %{"name" => name, "arguments" => args}
      }) do
    result = dispatch(name, args)
    respond(conn, %{
      jsonrpc: "2.0",
      id: id,
      result: %{content: [%{type: "text", text: Jason.encode!(result)}]}
    })
  end

  def handle(conn, %{"id" => id}) do
    respond(conn, %{
      jsonrpc: "2.0",
      id: id,
      error: %{code: -32601, message: "Method not found"}
    })
  end

  # JSON-RPC notifications have no "id" — acknowledge with 204, no body.
  def handle(conn, _params) do
    send_resp(conn, 204, "")
  end

  # ---------------------------------------------------------------------------
  # Streamable HTTP transport: respond as SSE or plain JSON based on Accept
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Tool dispatcher
  # ---------------------------------------------------------------------------

  defp dispatch("get_today", _args) do
    %{today: Date.to_iso8601(Clock.today())}
  end

  defp dispatch("list_items", %{"date" => date_str}) do
    with {:ok, date} <- Date.from_iso8601(date_str) do
      Lists.get_items_for_date(date) |> Enum.map(&ItemJSON.item/1)
    end
  end

  defp dispatch("list_items_range", args) do
    with {:ok, from} <- Date.from_iso8601(args["from"]),
         {:ok, to} <- Date.from_iso8601(args["to"]) do
      statuses = args["statuses"] && Enum.map(args["statuses"], &String.to_existing_atom/1)
      Lists.get_items_for_range(from, to, statuses) |> Enum.map(&ItemJSON.item/1)
    end
  end

  defp dispatch("add_item", %{"date" => date_str, "body" => body}) do
    body = Emoji.convert(body)
    with {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, [item]} <- Lists.create_items(date, [%{body: body}]) do
      ItemJSON.item(item)
    end
  end

  defp dispatch("update_item", %{"id" => id} = args) do
    attrs = args |> Map.drop(["id"]) |> convert_body()

    with {:ok, item} <- fetch_item(id),
         {:ok, updated} <- Lists.update_item(item, attrs) do
      ItemJSON.item(updated)
    end
  end

  defp dispatch("arrow_item", %{"id" => id, "target_date" => target_date_str}) do
    with {:ok, item} <- fetch_item(id),
         {:ok, target_date} <- DateHelper.resolve(target_date_str),
         {:ok, original, _copy} <- Lists.arrow_item(item, target_date) do
      ItemJSON.item(original)
    end
  end

  defp dispatch("search_items", %{"query" => query}) do
    SearchIndex.search(query)
    |> Enum.map(fn {id, date, body} ->
      %{id: id, date: Date.to_iso8601(date), body: body}
    end)
  end

  defp dispatch(_name, _args) do
    %{error: "unknown tool"}
  end

  # ---------------------------------------------------------------------------
  # Tool schema definitions
  # ---------------------------------------------------------------------------

  defp tool_definitions do
    [
      %{
        name: "get_today",
        description: "Get the current date in the user's local timezone (America/Denver)",
        inputSchema: %{type: "object", properties: %{}, required: []}
      },
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
      },
      %{
        name: "list_items_range",
        description: "Get items across a date range, optionally filtered by status",
        inputSchema: %{
          type: "object",
          properties: %{
            from: %{type: "string", description: "Start date ISO 8601"},
            to: %{type: "string", description: "End date ISO 8601"},
            statuses: %{
              type: "array",
              items: %{type: "string", enum: ["active", "completed", "wiggled_out", "arrowed_out"]},
              description: "Filter by these statuses (omit for all)"
            }
          },
          required: ["from", "to"]
        }
      },
      %{
        name: "add_item",
        description: "Add a new item to a date's list",
        inputSchema: %{
          type: "object",
          properties: %{
            date: %{type: "string", description: "ISO 8601 date"},
            body: %{type: "string", description: "Item text"}
          },
          required: ["date", "body"]
        }
      },
      %{
        name: "update_item",
        description: "Edit an existing item's body, status, color, or priority",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Item ID"},
            body: %{type: "string"},
            status: %{
              type: "string",
              enum: ["active", "completed", "wiggled_out"]
            },
            color: %{type: "string", enum: ["red", "blue", "green", "purple", "orange"]},
            priority: %{type: "string", enum: ["❶", "❷", "❸", "⭐", "🔥"]}
          },
          required: ["id"]
        }
      },
      %{
        name: "arrow_item",
        description: "Move an active item forward to another date",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Item ID"},
            target_date: %{type: "string", description: "ISO 8601 target date, or 'tomorrow'"}
          },
          required: ["id", "target_date"]
        }
      },
      %{
        name: "search_items",
        description: "Full-text search across all items",
        inputSchema: %{
          type: "object",
          properties: %{
            query: %{type: "string", description: "Search query"}
          },
          required: ["query"]
        }
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp convert_body(%{"body" => body} = attrs), do: Map.put(attrs, "body", Emoji.convert(body))
  defp convert_body(attrs), do: attrs

  defp fetch_item(id) do
    case Repo.get(ListItem, id) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end
end
