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

  @doc """
  Resolve cross-module references in a parsed YANG module.

  Takes a parsed module struct and an optional registry of known modules
  (`%{module_name => %Module{}}`). Runs the full 6-phase resolver pipeline:
  imports, types, identities, groupings, augments, deviations.

  Returns `{:ok, %ResolvedModule{}}` or `{:error, diagnostics}`.
  """
  @spec resolve(struct(), map()) :: {:ok, ExYang.Resolver.ResolvedModule.t()} | {:error, term()}
  def resolve(module, registry \\ %{}) do
    ExYang.Resolver.resolve(module, registry)
  end

  @doc """
  Encode a YANG model struct back to YANG source text.

  Returns `{:ok, yang_source}`.
  """
  @spec encode(struct()) :: {:ok, String.t()}
  defdelegate encode(module), to: ExYang.Encoder.Encoder

  @doc """
  Format a YANG model struct to canonical style.

  Returns `{:ok, yang_source}`.
  """
  @spec format(struct()) :: {:ok, String.t()}
  defdelegate format(module), to: ExYang.Encoder.Formatter
end
