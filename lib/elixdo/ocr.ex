defmodule Elixdo.OCR do
  @callback extract_items(binary()) :: {:ok, [String.t()]} | {:error, term()}
  def extract_items(image_data), do: impl().extract_items(image_data)
  defp impl, do: Application.get_env(:elixdo, :ocr, Elixdo.OCR.OpenAI)
end

defmodule Elixdo.OCR.OpenAI do
  @behaviour Elixdo.OCR
  def extract_items(_image_data) do
    # Phase 9 implementation
    {:error, :not_implemented}
  end
end
