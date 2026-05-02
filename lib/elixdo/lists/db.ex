defmodule Elixdo.Lists.DB do
  import Ecto.Query
  alias Elixdo.{Repo, ListItem}

  def get_items_for_date(date) do
    Repo.all(from i in ListItem, where: i.date == ^date, order_by: i.position)
  end

  def get_items_for_range(from_date, to_date, statuses \\ nil) do
    query =
      from i in ListItem,
        where: i.date >= ^from_date and i.date <= ^to_date,
        order_by: [i.date, i.position]

    query = if statuses, do: where(query, [i], i.status in ^statuses), else: query
    Repo.all(query)
  end

  def create_items(date, items_attrs) when is_list(items_attrs) do
    max_pos =
      Repo.one(
        from i in ListItem,
          where: i.date == ^date,
          select: max(i.position)
      ) || 0

    items_attrs
    |> Enum.with_index(1)
    |> Enum.reduce(Ecto.Multi.new(), fn {attrs, idx}, multi ->
      normalized = normalize_keys(attrs)

      changeset =
        ListItem.changeset(
          %ListItem{},
          Map.merge(normalized, %{"date" => date, "position" => max_pos + idx})
        )

      Ecto.Multi.insert(multi, {:item, idx}, changeset)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        items = result |> Map.values() |> Enum.sort_by(& &1.position)
        {:ok, items}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  @valid_transitions %{
    active: [:completed, :wiggled_out, :arrowed_out],
    completed: [:active],
    wiggled_out: [:active],
    arrowed_out: [:active]
  }

  def update_item(%ListItem{} = item, attrs) do
    case Map.get(attrs, :status) || Map.get(attrs, "status") do
      nil ->
        item |> ListItem.changeset(attrs) |> Repo.update()

      new_status when is_atom(new_status) ->
        allowed = Map.get(@valid_transitions, item.status, [])

        if new_status == item.status or new_status in allowed do
          item |> ListItem.changeset(attrs) |> Repo.update()
        else
          {:error, :forbidden_transition}
        end

      new_status when is_binary(new_status) ->
        normalized =
          attrs |> Map.delete("status") |> Map.put(:status, String.to_existing_atom(new_status))

        update_item(item, normalized)
    end
  end

  def arrow_item(%ListItem{status: :active} = item, to_date) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :original,
      ListItem.changeset(item, %{status: :arrowed_out, arrowed_to_date: to_date})
    )
    |> Ecto.Multi.run(:copy, fn _repo, _changes ->
      create_items(to_date, [
        %{
          body: item.body,
          color: item.color,
          bold: item.bold,
          italic: item.italic,
          highlighted: item.highlighted,
          prefix: item.prefix
        }
      ])
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{original: original, copy: [copy]}} ->
        {:ok, original, copy}

      {:ok, %{original: original, copy: copy}} when is_list(copy) ->
        {:ok, original, List.first(copy)}

      {:error, _, reason, _} ->
        {:error, reason}
    end
  end

  def arrow_item(%ListItem{}, _to_date), do: {:error, :forbidden_transition}

  def reorder_items(date, ordered_ids) when is_list(ordered_ids) do
    existing = get_items_for_date(date)
    existing_ids = Enum.map(existing, & &1.id) |> MapSet.new()
    given_ids = MapSet.new(ordered_ids)

    if MapSet.equal?(existing_ids, given_ids) do
      ordered_ids
      |> Enum.with_index(1)
      |> Enum.reduce(Ecto.Multi.new(), fn {id, pos}, multi ->
        item = Enum.find(existing, &(&1.id == id))
        Ecto.Multi.update(multi, {:pos, id}, ListItem.changeset(item, %{position: pos}))
      end)
      |> Repo.transaction()
      |> case do
        {:ok, _} -> {:ok, get_items_for_date(date)}
        error -> error
      end
    else
      {:error, :partial_reorder}
    end
  end
end
