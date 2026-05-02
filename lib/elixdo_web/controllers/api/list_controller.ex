defmodule ElixdoWeb.Api.ListController do
  use ElixdoWeb, :controller

  alias Elixdo.{Lists, DateHelper}

  # GET /api/v1/lists/:date
  def show(conn, %{"date" => date_str}) do
    with {:ok, date} <- DateHelper.resolve(date_str) do
      items = Lists.get_items_for_date(date)
      json(conn, %{data: Enum.map(items, &item_json/1)})
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "invalid_date", message: "Invalid date format"}})
    end
  end

  # GET /api/v1/lists?from=&to=&status=
  def index(conn, params) do
    with {:ok, from_date} <- DateHelper.resolve(Map.get(params, "from", "today")),
         {:ok, to_date} <- DateHelper.resolve(Map.get(params, "to", "today")) do
      statuses = parse_statuses(Map.get(params, "status"))
      items = Lists.get_items_for_range(from_date, to_date, statuses)
      json(conn, %{data: Enum.map(items, &item_json/1)})
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "invalid_date", message: "Invalid date format"}})
    end
  end

  # POST /api/v1/lists/:date/items
  def create_items(conn, %{"date" => date_str} = params) do
    raw_items = Map.get(params, "items", [])
    items_attrs = Enum.map(raw_items, &stringify_keys/1)

    with {:ok, date} <- DateHelper.resolve(date_str),
         {:ok, items} <- Lists.create_items(date, items_attrs) do
      conn
      |> put_status(201)
      |> json(%{data: Enum.map(items, &item_json/1)})
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "invalid_date", message: "Invalid date format"}})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "validation_error", message: format_errors(changeset)}})
    end
  end

  # PATCH /api/v1/lists/:date/reorder
  def reorder(conn, %{"date" => date_str, "ids" => ids}) when is_list(ids) do
    with {:ok, date} <- DateHelper.resolve(date_str),
         {:ok, items} <- Lists.reorder_items(date, ids) do
      json(conn, %{data: Enum.map(items, &item_json/1)})
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "invalid_date", message: "Invalid date format"}})

      {:error, :partial_reorder} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "partial_reorder", message: "IDs do not match items on this date"}})

      {:error, _} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "reorder_failed", message: "Failed to reorder items"}})
    end
  end

  def reorder(conn, %{"date" => _date_str}) do
    conn
    |> put_status(422)
    |> json(%{error: %{code: "validation_error", message: "ids must be a list"}})
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_keys(other), do: other

  defp parse_statuses(nil), do: nil
  defp parse_statuses(""), do: nil

  defp parse_statuses(status_str) when is_binary(status_str) do
    status_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_existing_atom/1)
  rescue
    ArgumentError -> nil
  end

  defp parse_statuses(statuses) when is_list(statuses) do
    Enum.map(statuses, &String.to_existing_atom/1)
  rescue
    ArgumentError -> nil
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> inspect()
  end

  defp format_errors(_), do: "Validation failed"

  def item_json(item) do
    %{
      id: item.id,
      date: Date.to_iso8601(item.date),
      body: item.body,
      status: to_string(item.status),
      position: item.position,
      bold: item.bold,
      italic: item.italic,
      highlighted: item.highlighted,
      color: item.color && to_string(item.color),
      prefix: item.prefix,
      arrowed_to_date: item.arrowed_to_date && Date.to_iso8601(item.arrowed_to_date),
      inserted_at: format_datetime(item.inserted_at),
      updated_at: format_datetime(item.updated_at)
    }
  end

  defp format_datetime(%DateTime{} = dt) do
    dt |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp format_datetime(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("UTC")
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp format_datetime(nil), do: nil
end
