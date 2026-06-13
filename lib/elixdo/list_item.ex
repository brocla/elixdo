defmodule Elixdo.ListItem do
  @moduledoc "Ecto schema for a single task item. Defines fields, enums, and validation rules."

  use Ecto.Schema
  import Ecto.Changeset

  @valid_priorities ["❶", "❷", "❸", "⭐", "🔥", "⛪"]

  schema "list_items" do
    field :date, :date
    field :position, :integer
    field :body, :string

    field :status, Ecto.Enum,
      values: [:active, :completed, :wiggled_out, :arrowed_out],
      default: :active

    field :color, Ecto.Enum, values: [:red, :blue, :green, :purple, :orange]
    field :priority, :string
    field :arrowed_to_date, :date

    timestamps(type: :utc_datetime)
  end

  def colors, do: Ecto.Enum.values(__MODULE__, :color)
  def color_strings, do: Enum.map(colors(), &Atom.to_string/1)
  def priorities, do: @valid_priorities

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :date,
      :position,
      :body,
      :status,
      :color,
      :priority,
      :arrowed_to_date
    ])
    |> validate_required([:date, :position, :body])
    |> validate_length(:body, min: 1)
    |> validate_priority()
    |> validate_arrowed_to_date_consistency()
  end

  defp validate_priority(changeset) do
    case get_change(changeset, :priority) do
      nil -> changeset
      p when p in @valid_priorities -> changeset
      _ -> add_error(changeset, :priority, "must be one of #{Enum.join(@valid_priorities, ", ")}")
    end
  end

  # arrowed_to_date must be set iff status is arrowed_out
  defp validate_arrowed_to_date_consistency(changeset) do
    status = get_field(changeset, :status)
    arrowed_to_date = get_field(changeset, :arrowed_to_date)

    cond do
      status == :arrowed_out and is_nil(arrowed_to_date) ->
        add_error(changeset, :arrowed_to_date, "must be set when status is arrowed_out")

      status != :arrowed_out and not is_nil(arrowed_to_date) ->
        add_error(changeset, :arrowed_to_date, "must be nil when status is not arrowed_out")

      true ->
        changeset
    end
  end
end
