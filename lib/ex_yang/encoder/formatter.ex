defmodule ExYang.Encoder.Formatter do
  @moduledoc "Formats YANG model structs to canonical style."

  alias ExYang.Encoder.Encoder

  @spec format(struct()) :: {:ok, String.t()}
  def format(node), do: Encoder.encode(node)
end
