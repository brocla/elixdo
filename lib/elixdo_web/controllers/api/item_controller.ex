defmodule ElixdoWeb.Api.ItemController do
  use ElixdoWeb, :controller

  alias Elixdo.{Lists, DateHelper}
  alias ElixdoWeb.Api.{ItemJSON, Helpers}

  # PATCH /api/v1/items/:id
  def update(conn, %{"id" => id} = params) do
    with {:ok, item} <- fetch_item(id),
         attrs <- Map.drop(params, ["id"]),
         {:ok, updated} <- Lists.update_item(item, attrs) do
      json(conn, %{data: ItemJSON.item(updated)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: %{code: "not_found", message: "Item not found"}})

      {:error, :forbidden_transition} ->
        conn
        |> put_status(422)
        |> json(%{
          error: %{code: "forbidden_transition", message: "Status transition is not allowed"}
        })

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "validation_error", message: ItemJSON.format_errors(changeset)}})
    end
  end

  # POST /api/v1/items/:id/arrow
  def arrow(conn, %{"id" => id, "target_date" => target_date_str}) do
    with {:ok, item} <- fetch_item(id),
         {:ok, target_date} <- DateHelper.resolve(target_date_str),
         {:ok, original, _copy} <- Lists.arrow_item(item, target_date) do
      json(conn, %{data: ItemJSON.item(original)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: %{code: "not_found", message: "Item not found"}})

      {:error, :invalid_date} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "invalid_date", message: "Invalid target date format"}})

      {:error, :forbidden_transition} ->
        conn
        |> put_status(422)
        |> json(%{
          error: %{code: "forbidden_transition", message: "Only active items can be arrowed"}
        })

      {:error, _} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "arrow_failed", message: "Failed to arrow item"}})
    end
  end

  def arrow(conn, %{"id" => _id}) do
    conn
    |> put_status(422)
    |> json(%{error: %{code: "validation_error", message: "target_date is required"}})
  end

  defp fetch_item(id), do: Helpers.fetch_item(id)
end
