defmodule ExYang do
  @moduledoc """
  YANG (RFC 7950) parser, resolver, and data modeling library for Elixir.

  ## Types

  ExYang targets Elixir 1.20 and is written for its set-theoretic type
  checker. The checker infers types from function bodies, guards, and
  struct patterns and reports redundant clauses and incompatible calls at
  compile time; the library compiles clean under it.

  `@spec` and `@type` declarations are not consumed by the 1.20 checker
  (signatures are a later milestone upstream). They serve as the
  documented contract for callers, ExDoc, and Dialyzer:

  * Every public function carries a `@spec`.
  * Every `ExYang.Model.*` struct declares a `t()` with concrete field
    types; `ExYang.Model.Common` holds the shared unions
    (`t:schema_module/0`, `t:data_def/0`, `t:body_node/0`, `t:model_node/0`).
  * Intermediate representations are typed too:
    `t:ExYang.Parser.Lexer.token/0`, `t:ExYang.Parser.Grammar.statement/0`,
    `t:ExYang.XPath.ast/0`, `t:ExYang.Resolver.namespace_map/0`.

  A test (`test/ex_yang/typespec_test.exs`) fails if a public function
  in the `ExYang` namespace is added without a `@spec`.

  ## Examples

      iex> {:ok, %ExYang.Model.Module{} = mod} = ExYang.parse("module t { namespace \\"urn:t\\"; prefix t; leaf x { type string; } }")
      iex> [%ExYang.Model.Leaf{type: %ExYang.Model.Type{name: "string"}}] = mod.body
      iex> mod.name
      "t"
  """

  @doc """
  Parse a YANG source string into a typed module struct.

  Returns `{:ok, module}` where `module` is a `%ExYang.Model.Module{}` or
  `%ExYang.Model.Submodule{}` (see `t:ExYang.Model.Common.schema_module/0`),
  or `{:error, reason}`.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> mod.name
      "test"

      iex> {:error, _} = ExYang.parse("invalid {")
  """
  @spec parse(String.t()) :: {:ok, ExYang.Model.Common.schema_module()} | {:error, term()}
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
  @spec parse!(String.t()) :: ExYang.Model.Common.schema_module()
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
  @spec resolve(ExYang.Model.Common.schema_module(), ExYang.Resolver.registry()) ::
          {:ok, ExYang.Resolver.ResolvedModule.t()} | {:error, [ExYang.Diagnostic.t()]}
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
  @spec encode(ExYang.Model.Common.model_node()) :: {:ok, String.t()}
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
  @spec format(ExYang.Model.Common.model_node()) :: {:ok, String.t()}
  def format(module), do: ExYang.Encoder.Formatter.format(module)
end
