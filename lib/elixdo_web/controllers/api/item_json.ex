defmodule ElixdoWeb.Api.ItemJSON do
  alias Elixdo.ListItem

  @doc "Serialize a single ListItem to a JSON-safe map."
  def item(%ListItem{} = item) do
    %{
      id: item.id,
      date: Date.to_iso8601(item.date),
      body: item.body,
      status: to_string(item.status),
      position: item.position,
      color: item.color && to_string(item.color),
      arrowed_to_date: item.arrowed_to_date && Date.to_iso8601(item.arrowed_to_date),
      inserted_at: format_datetime(item.inserted_at),
      updated_at: format_datetime(item.updated_at)
    }
  end

  @doc "Format a changeset's errors into a human-readable string."
  def format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> inspect()
  end

  def format_errors(_), do: "Validation failed"

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
