defmodule ExYang do
  @moduledoc """
  YANG (RFC 7950) parser, resolver, and data modeling library for Elixir.
  """

  @doc """
  Parse a YANG source string into a typed module struct.

  Returns `{:ok, module_struct}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> mod.name
      "test"

      iex> {:error, _} = ExYang.parse("invalid {")
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
  Parse a YANG source string, raising on error.

  ## Examples

      iex> mod = ExYang.parse!("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> mod.name
      "test"
  """
  @spec parse!(String.t()) :: struct()
  def parse!(source) do
    case parse(source) do
      {:ok, module} -> module
      {:error, reason} -> raise "ExYang parse error: #{inspect(reason)}"
    end
  end

  @doc """
  Resolve a parsed module against a registry of other modules.

  Runs the six-phase resolution pipeline: imports, identities,
  groupings, augments, deviations, and types.

  Takes a parsed module struct and an optional registry of known modules
  (`%{module_name => %Module{}}`).

  Returns `{:ok, %ResolvedModule{}}` or `{:error, diagnostics}`.
  """
  @spec resolve(struct(), map()) :: {:ok, ExYang.Resolver.ResolvedModule.t()} | {:error, term()}
  def resolve(module, registry \\ %{}) do
    ExYang.Resolver.resolve(module, registry)
  end

  @doc """
  Encode a module struct back to YANG source text (round-trip faithful).

  Returns `{:ok, yang_source}`.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> {:ok, yang} = ExYang.encode(mod)
      iex> yang =~ "module test"
      true
  """
  @spec encode(struct()) :: {:ok, String.t()}
  def encode(module), do: ExYang.Encoder.Encoder.encode(module)

  @doc """
  Format a module struct to canonical YANG style.

  Returns `{:ok, yang_source}`.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> {:ok, yang} = ExYang.format(mod)
      iex> yang =~ "module test"
      true
  """
  @spec format(struct()) :: {:ok, String.t()}
  def format(module), do: ExYang.Encoder.Formatter.format(module)
end
