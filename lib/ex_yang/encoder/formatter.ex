defmodule ExYang.Encoder.Formatter do
  @moduledoc "Formats YANG model structs to canonical style."

  alias ExYang.Encoder.Encoder

  @doc """
  Format a YANG model struct to canonical style.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> {:ok, yang} = ExYang.Encoder.Formatter.format(mod)
      iex> yang =~ "module test"
      true
  """
  @spec format(struct()) :: {:ok, String.t()}
  def format(node), do: Encoder.encode(node)
end
