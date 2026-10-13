# ExYang

YANG ([RFC 7950](https://datatracker.ietf.org/doc/html/rfc7950)) parser, resolver, and data modeling library for Elixir.

ExYang parses YANG modules into typed Elixir structs, resolves cross-module references (imports, typedefs, groupings, augments, deviations, identities), encodes back to YANG source with round-trip fidelity, and persists modules in an Ecto-backed registry.

## Installation

Add `ex_yang` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_yang, "~> 0.2.0"},
    # Pick your database adapter:
    {:ecto_sqlite3, "~> 0.17"},  # or
    {:postgrex, "~> 0.19"}
  ]
end
```

## Quick Start

### Parse

```elixir
yang = """
module my-network {
  namespace "urn:example:my-network";
  prefix net;

  container interfaces {
    list interface {
      key "name";
      leaf name {
        type string;
      }
      leaf mtu {
        type uint16;
      }
    }
  }
}
"""

{:ok, mod} = ExYang.parse(yang)
mod.name         #=> "my-network"
mod.prefix       #=> "net"
[container] = mod.body
container.name   #=> "interfaces"
```

### Encode (Round-Trip)

```elixir
{:ok, yang_source} = ExYang.encode(mod)
# Produces valid YANG that can be parsed again
{:ok, ^mod_name} = ExYang.parse(yang_source) |> elem(1) |> Map.fetch(:name)
```

### Format (Canonical)

```elixir
{:ok, formatted} = ExYang.format(mod)
# Canonical style: 2-space indent, double quotes, RFC 7950 statement ordering
```

### Resolve Cross-Module References

```elixir
# Parse dependency modules
{:ok, types_mod} = ExYang.parse(File.read!("ietf-yang-types.yang"))

# Build a registry
registry = %{"ietf-yang-types" => types_mod}

# Resolve: expands groupings, applies augments/deviations, resolves typedefs
{:ok, resolved} = ExYang.resolve(mod, registry)

resolved.module          # fully resolved %Module{} — no uses/groupings remaining
resolved.namespace_map   # %{"yang" => %Module{...}}
resolved.identity_graph  # identity inheritance DAG
resolved.diagnostics     # warnings accumulated during resolution
```

### Ecto Registry

Persist parsed modules in SQLite or Postgres:

```elixir
# In your app's repo config
config :ex_yang, ExYang.TestRepo,
  database: "yang_registry.sqlite3"

# Run migrations
Ecto.Migrator.run(MyRepo, [{0, ExYang.Registry.Migrations.V01}], :up)

# Store and fetch
{:ok, id} = ExYang.Registry.EctoRegistry.store(mod, yang_source, MyRepo)
{:ok, fetched} = ExYang.Registry.EctoRegistry.fetch("my-network", nil, MyRepo)
```

## Architecture

Two-pass parser exploiting YANG's uniform syntax (`keyword [argument] { sub-statements }` / `keyword argument ;`):

1. **NimbleParsec lexer/grammar** produces a generic tree of `{keyword, argument, sub_statements, meta}` tuples
2. **Transform layer** converts the generic tree into ~35 typed structs, validates sub-statement cardinality, and handles extensions

```
YANG source
  |> Lexer (NimbleParsec tokenization)
  |> Grammar (generic tree)
  |> CommentAttacher (attach comments for round-trip)
  |> Builder (typed structs)
  |> Validator (RFC 7950 cardinality rules)
  => %Module{}
```

### Resolution Pipeline

Cross-module resolution runs six phases in order:

1. **Import/Include** -- builds namespace map from registry
2. **Identity** -- builds inheritance DAG
3. **Grouping** -- expands `uses` statements inline
4. **Augment** -- inserts nodes at target schema paths
5. **Deviation** -- modifies/removes nodes per deviation rules
6. **Type** -- resolves typedef chains to built-in base types

### Model Structs

Every YANG statement type has a corresponding Elixir struct:

| Category | Structs |
|---|---|
| Module | `Module`, `Submodule` |
| Header | `Import`, `Include`, `Revision`, `BelongsTo` |
| Data Definition | `Container`, `Leaf`, `LeafList`, `List`, `Choice`, `Case`, `AnyData`, `AnyXml` |
| Schema | `Grouping`, `Uses`, `Refine`, `Augment`, `Deviation`, `Deviate` |
| Type System | `Typedef`, `Type`, `Enum`, `Bit` |
| Identity | `Identity`, `Feature` |
| RPC | `Rpc`, `Action`, `Input`, `Output`, `Notification` |
| Constraints | `Must`, `When`, `Range`, `Length`, `Pattern` |
| Extensions | `ExtensionDef`, `ExtensionUse` |

All structs carry `meta` (source position for round-trip) and `comments` fields.

### XPath Parser

YANG `when` and `must` statements use XPath 1.0 expressions. ExYang includes a subset parser:

```elixir
{:ok, ast} = ExYang.XPath.parse("derived-from-or-self(type, 'ianaift:ethernetCsmacd')")
ExYang.XPath.format(ast)
#=> "derived-from-or-self(type, 'ianaift:ethernetCsmacd')"
```

Parses but does not evaluate. The AST is stored in `%Must{}` and `%When{}` for consumer inspection.

### Extension System

Unknown YANG extensions are parsed as opaque `%ExtensionUse{}` nodes. Register custom handlers:

```elixir
defmodule MyExtHandler do
  @behaviour ExYang.Transform.Extensions

  @impl true
  def transform({"mymod", "custom"}, arg, _subs, _meta) do
    {:ok, %MyCustomStruct{value: arg}}
  end

  def transform(_, _, _, _), do: :skip
end

ExYang.Transform.Extensions.register({"mymod", "custom"}, MyExtHandler)
```

## RFC Coverage

- RFC 7950 -- YANG 1.1 (full core language)
- Pluggable extension system for RFC 8040, 8791, 9195, and custom extensions
- IETF standard type libraries (`ietf-yang-types`, `ietf-inet-types`)

Tested against real IETF modules: `ietf-yang-types@2013-07-15`, `ietf-inet-types@2013-07-15`, `ietf-interfaces@2018-02-20`.

## Requirements

- Elixir 1.20+ (OTP 27+)
- Optional: `ecto_sqlite3` or `postgrex` for the Ecto registry

## Types

ExYang is written for the Elixir 1.20 set-theoretic type checker and
compiles clean under it. The checker works by inference (function bodies,
guards, struct patterns), so it needs no annotations; the `@spec` and
`@type` declarations in the library are the documented contract for
callers, ExDoc, and Dialyzer.

- Every public function has a `@spec`; a test fails if one is added without.
- Every `ExYang.Model.*` struct has a `t()` with concrete field types.
  `ExYang.Model.Common` defines the shared unions: `t:ExYang.Model.Common.schema_module/0`
  (`Module.t() | Submodule.t()`), `t:ExYang.Model.Common.data_def/0`, `t:ExYang.Model.Common.body_node/0`, `t:ExYang.Model.Common.model_node/0`.
- Intermediate representations are typed: `t:ExYang.Lexer.token/0`,
  `t:ExYang.Grammar.statement/0`, `t:ExYang.XPath.ast/0`, `t:ExYang.Resolver.namespace_map/0`.

```elixir
@spec ExYang.parse(String.t()) :: {:ok, ExYang.Model.Common.schema_module()} | {:error, term()}
@spec ExYang.resolve(ExYang.Model.Common.schema_module(), ExYang.Resolver.registry()) ::
        {:ok, ExYang.Resolver.ResolvedModule.t()} | {:error, [ExYang.Diagnostic.t()]}
```

## License

AGPL-3.0-only
