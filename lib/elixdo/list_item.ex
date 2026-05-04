defmodule Elixdo.ListItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "list_items" do
    field :date, :date
    field :position, :integer
    field :body, :string

    field :status, Ecto.Enum,
      values: [:active, :completed, :wiggled_out, :arrowed_out],
      default: :active

    field :color, Ecto.Enum, values: [:red, :blue, :green, :purple, :orange]
    field :bold, :boolean, default: false
    field :italic, :boolean, default: false
    field :highlighted, :boolean, default: false
    field :prefix, :string
    field :arrowed_to_date, :date

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :date,
      :position,
      :body,
      :status,
      :color,
      :bold,
      :italic,
      :highlighted,
      :prefix,
      :arrowed_to_date
    ])
    |> validate_required([:date, :position, :body])
    |> validate_length(:body, min: 1)
    |> validate_arrowed_to_date_consistency()
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
