defmodule ExYang do
  @moduledoc """
  YANG (RFC 7950) parser, resolver, and data modeling library for Elixir.
  """

  @doc """
  Parse a YANG source string into a typed model struct.

  Returns `{:ok, module_struct}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, struct()} | {:error, term()}
  def parse(source) when is_binary(source) do
    with {:ok, statements, comments, blank_lines} <- ExYang.Parser.Grammar.parse(source),
         statements <- ExYang.Parser.CommentAttacher.attach(statements, comments, blank_lines),
         {:ok, module} <- ExYang.Transform.Builder.build(hd(statements)),
         {:ok, module} <- ExYang.Transform.Validator.validate(module) do
      {:ok, module}
    end
  end

  @doc """
  Parse a YANG source string, raising on failure.
  """
  @spec parse!(String.t()) :: struct()
  def parse!(source) do
    case parse(source) do
      {:ok, module} -> module
      {:error, reason} -> raise "ExYang parse error: #{inspect(reason)}"
    end
  end
end
