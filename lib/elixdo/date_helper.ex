defmodule Elixdo.DateHelper do
  @moduledoc "Resolves date strings to Date.t() in America/Denver timezone."

  @spec resolve(String.t() | Date.t()) :: {:ok, Date.t()} | {:error, :invalid_date}
  def resolve(date) when is_struct(date, Date), do: {:ok, date}
  def resolve("today"),     do: {:ok, Elixdo.Clock.today()}
  def resolve("yesterday"), do: {:ok, Date.add(Elixdo.Clock.today(), -1)}
  def resolve("tomorrow"),  do: {:ok, Date.add(Elixdo.Clock.today(), 1)}
  def resolve(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end
  def resolve(_), do: {:error, :invalid_date}
end
