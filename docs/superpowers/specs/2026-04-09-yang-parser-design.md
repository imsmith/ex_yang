# ExYang — YANG Parser & Data Modeling Library for Elixir

**Date:** 2026-04-09
**Status:** Approved
**License:** AGPL-3.0-only

## Purpose

ExYang is a full YANG (RFC 7950) parser, resolver, and round-trip encoder for Elixir. Its primary use case is architectural data modeling — defining data models independently from database schemas, API specs, or wire formats, then using those models as the canonical source of truth to drive downstream artifacts (type registries, API client generation, schema validation, etc.).

The BEAM/Elixir ecosystem has no current YANG tooling. The only prior art is a 10-year-old rebar plugin that predates significant YANG 1.1 and post-7950 RFC updates.

## Scope

Full IETF standards sweep:

- RFC 7950 — YANG 1.1 (core language)
- RFC 8040 — RESTCONF YANG extensions
- RFC 8294, 8341, 8342 — datastores, NACM, hardware models
- RFC 8791 — YANG Data Structure Extensions (`sx:structure`)
- RFC 9195 — YANG module versioning
- IETF standard type libraries (`ietf-yang-types`, `ietf-inet-types`, etc.)
- Pluggable extension system for custom and future extensions

## Architecture Overview

Two-pass parser with intermediate representation:

1. **NimbleParsec lexer/grammar** produces a generic tree of `{keyword, argument, sub_statements, meta}` tuples — exploiting YANG's uniform `keyword [argument] { sub-statements }` / `keyword argument ;` syntax
2. **Transform layer** converts the generic tree into typed structs, validates sub-statement cardinality, and handles extensions

Cross-module resolution is a separate pipeline that operates on parsed modules stored in an Ecto-backed registry.

## Target

- Elixir 1.17+ / OTP 27+
- Project name: `ex_yang`, top-level module: `ExYang`

## Project Structure

```
ex_yang/
├── lib/
│   ├── ex_yang.ex                    # Public API: parse/1, parse!/1, encode/1, format/1
│   ├── ex_yang/
│   │   ├── parser/
│   │   │   ├── lexer.ex              # NimbleParsec tokenizer
│   │   │   ├── grammar.ex            # NimbleParsec generic tree parser
│   │   │   └── comment_attacher.ex   # Post-parse comment attachment
│   │   ├── transform/
│   │   │   ├── builder.ex            # Generic tree -> typed structs
│   │   │   ├── validator.ex          # Sub-statement cardinality & rules
│   │   │   └── extensions.ex         # Extension handler registry
│   │   ├── model/
│   │   │   ├── module.ex             # %Module{}, %Submodule{}
│   │   │   ├── data_def.ex           # %Container{}, %Leaf{}, %LeafList{}, %List{}, %Choice{}, %Case{}
│   │   │   ├── schema.ex             # %Grouping{}, %Uses{}, %Augment{}, %Deviation{}, %Deviate{}, %Refine{}
│   │   │   ├── type.ex               # %Typedef{}, %Type{}, %Enum{}, %Bit{}, built-in type definitions
│   │   │   ├── identity.ex           # %Identity{}, %Feature{}
│   │   │   ├── rpc.ex                # %Rpc{}, %Action{}, %Input{}, %Output{}, %Notification{}
│   │   │   ├── constraint.ex         # %Must{}, %When{}, %Range{}, %Length{}, %Pattern{}
│   │   │   ├── header.ex             # %Import{}, %Include{}, %Revision{}, %BelongsTo{}
│   │   │   ├── common.ex             # Shared meta struct, common fields
│   │   │   └── extension.ex          # %ExtensionDef{}, %ExtensionUse{}
│   │   ├── resolver/
│   │   │   ├── resolver.ex           # Orchestrates full resolution pipeline
│   │   │   ├── import_resolver.ex    # Resolves import/include chains
│   │   │   ├── grouping_resolver.ex  # Expands uses -> grouping inline
│   │   │   ├── augment_resolver.ex   # Applies augments to target paths
│   │   │   ├── deviation_resolver.ex # Applies deviations
│   │   │   ├── type_resolver.ex      # Resolves typedef chains to base types
│   │   │   └── identity_resolver.ex  # Builds identity inheritance graph
│   │   ├── registry/
│   │   │   ├── registry.ex           # Behaviour for module storage
│   │   │   ├── repo.ex               # Ecto repo (adapter-agnostic)
│   │   │   ├── schema/               # Ecto schemas for modules, relationships, identities
│   │   │   └── migrations/           # Ecto migrations
│   │   ├── encoder/
│   │   │   ├── encoder.ex            # Round-trip faithful encoding
│   │   │   └── formatter.ex          # Canonical formatting
│   │   └── xpath/
│   │       └── xpath.ex              # XPath 1.0 subset parser (for when/must)
├── test/
│   ├── fixtures/                     # Sample .yang files from RFCs
│   └── ...
```

## Dependencies

- `nimble_parsec` ~> 1.4 — lexer and generic grammar
- `ecto` ~> 3.12 — registry persistence
- `ecto_sqlite3` ~> 0.17 — SQLite adapter (optional dep)
- `postgrex` ~> 0.19 — Postgres adapter (optional dep)
- `ex_doc` ~> 0.34 — dev only

DB adapters are optional. The consuming app configures which adapter via its Ecto repo config.

## Parser — Lexer & Generic Grammar

### Lexer

Tokenizes YANG source into:

- `:keyword` — unquoted identifier, possibly prefixed (`prefix:name`)
- `:string` — single-quoted, double-quoted, or unquoted argument strings
- `:string_concat` — the `+` operator for string concatenation
- `:open_brace`, `:close_brace`, `:semicolon`
- `:line_comment` (`//`), `:block_comment` (`/* */`)
- `:newline`, `:whitespace` — preserved in token metadata for round-trip

Each token carries `%{line: n, column: n, offset: n}` metadata.

### Grammar

Produces a generic tree. The intermediate representation:

```elixir
{keyword, argument, sub_statements, meta}
```

- `keyword` — `{prefix, name}` tuple or just `name` atom
- `argument` — `nil` or a string (concatenation already resolved)
- `sub_statements` — list of the same tuple shape, recursively
- `meta` — `%{line: n, column: n, comments: [], whitespace: []}` for source positions and formatting data

Example — parsing:

```yang
container interfaces {
  description "Network interfaces";
  list interface {
    key "name";
    leaf name {
      type string;
    }
  }
}
```

Produces:

```elixir
{:container, "interfaces", [
  {:description, "Network interfaces", [], %{line: 2, ...}},
  {:list, "interface", [
    {:key, "name", [], %{line: 4, ...}},
    {:leaf, "name", [
      {:type, "string", [], %{line: 6, ...}}
    ], %{line: 5, ...}}
  ], %{line: 3, ...}}
], %{line: 1, ...}}
```

### String Handling

YANG allows double-quoted strings (with `\n`, `\t`, `\\`, `\"` escapes), single-quoted strings (literal, no escapes), and concatenation with `+`. The lexer handles quoting rules; the grammar resolves concatenation into a single string value but keeps original fragments in metadata for round-trip.

### Comment Attacher

Post-parse pass following the ex_hcl pattern — associates comments with their nearest statement node based on line proximity and blank-line separation. Leading, inline, and floating positions.

## Transform — Generic Tree to Typed Structs

### Builder

Dispatches on keyword to construct typed structs:

```elixir
defp build(:module, arg, subs, meta) do
  %Module{
    name: arg,
    namespace: take_one(subs, :namespace),
    prefix: take_one(subs, :prefix),
    imports: take_all(subs, :import),
    includes: take_all(subs, :include),
    revisions: take_all(subs, :revision),
    body: build_body(subs),
    typedefs: take_all(subs, :typedef),
    groupings: take_all(subs, :grouping),
    identities: take_all(subs, :identity),
    extensions: take_all(subs, :extension),
    rpcs: take_all(subs, :rpc),
    notifications: take_all(subs, :notification),
    augments: take_all(subs, :augment),
    deviations: take_all(subs, :deviation),
    meta: meta
  }
end
```

Every `build/4` clause follows this shape. Unknown keywords (extensions) are captured as `%ExtensionUse{}` nodes.

### Validator

Enforces RFC 7950 Section 14 grammar — sub-statement cardinality rules declared as data:

```elixir
@leaf_rules %{
  type:        {1, 1},
  default:     {0, 1},
  config:      {0, 1},
  mandatory:   {0, 1},
  status:      {0, 1},
  description: {0, 1},
  reference:   {0, 1},
  units:       {0, 1},
  must:        {0, :unbounded},
  when:        {0, 1},
  if_feature:  {0, :unbounded}
}
```

Rules are per statement type. Validation is a single generic function that walks the tree and checks against the rules. Returns `{:ok, module}` or `{:error, diagnostics}`.

### Extension Registry

A behaviour for pluggable extension handling:

```elixir
defmodule ExYang.Transform.Extensions do
  @callback transform(keyword :: {prefix, name}, argument, sub_statements, meta) ::
              {:ok, struct()} | :skip | {:error, String.t()}
end
```

Unregistered extensions become `%ExtensionUse{keyword: {prefix, name}, argument: arg, sub_statements: [...]}` — parsed but opaque. RFC 8791 `sx:structure`, RFC 9195 versioning, and custom extensions are handled through this mechanism.

## Model — Struct Hierarchy

~35 struct modules in `lib/ex_yang/model/`, grouped by role. Every struct carries `meta` (source position/formatting) and `comments` (for round-trip) fields.

### Header Statements

- `%Module{name, namespace, prefix, yang_version, imports, includes, revisions, organization, contact, description, reference, body, typedefs, groupings, identities, extensions, rpcs, notifications, augments, deviations, features, meta, comments}`
- `%Submodule{name, belongs_to, ...}` — same fields minus namespace, plus `belongs_to`
- `%Import{module, prefix, revision_date, description, reference, meta, comments}`
- `%Include{module, revision_date, description, reference, meta, comments}`
- `%Revision{date, description, reference, meta, comments}`
- `%BelongsTo{module, prefix, meta, comments}`

### Data Definition

- `%Container{name, config, presence, must, when, if_features, status, description, reference, typedefs, groupings, body, meta, comments}`
- `%Leaf{name, type, default, config, mandatory, must, when, if_features, status, units, description, reference, meta, comments}`
- `%LeafList{name, type, config, min_elements, max_elements, ordered_by, must, when, if_features, status, units, description, reference, meta, comments}`
- `%List{name, key, unique, config, min_elements, max_elements, ordered_by, must, when, if_features, status, description, reference, typedefs, groupings, body, meta, comments}`
- `%Choice{name, default, config, mandatory, must, when, if_features, status, description, reference, cases, meta, comments}`
- `%Case{name, when, if_features, status, description, reference, body, meta, comments}`
- `%AnyData{name, config, mandatory, must, when, if_features, status, description, reference, meta, comments}`
- `%AnyXml{name, config, mandatory, must, when, if_features, status, description, reference, meta, comments}`

### Schema Manipulation

- `%Grouping{name, status, description, reference, typedefs, groupings, body, meta, comments}`
- `%Uses{grouping, when, if_features, status, description, reference, refines, augments, meta, comments}`
- `%Refine{target_node, description, reference, config, default, mandatory, presence, must, min_elements, max_elements, meta, comments}`
- `%Augment{target_node, when, if_features, status, description, reference, body, meta, comments}`
- `%Deviation{target_node, description, reference, deviates, meta, comments}`
- `%Deviate{type, config, default, mandatory, must, min_elements, max_elements, type_replacement, units, unique, meta, comments}` — type is `:not_supported | :add | :replace | :delete`

### Type System

- `%Typedef{name, type, default, status, units, description, reference, meta, comments}`
- `%Type{name, base, range, length, patterns, fraction_digits, enum_values, bit_values, path, require_instance, union_types, meta, comments}` — polymorphic by which constraints are populated
- `%Enum{name, value, status, description, reference, if_features, meta, comments}`
- `%Bit{name, position, status, description, reference, if_features, meta, comments}`

### Identity & Feature

- `%Identity{name, bases, status, description, reference, if_features, meta, comments}`
- `%Feature{name, status, description, reference, if_features, meta, comments}`

### RPC / Action / Notification

- `%Rpc{name, input, output, typedefs, groupings, status, description, reference, if_features, meta, comments}`
- `%Action{name, input, output, typedefs, groupings, status, description, reference, if_features, meta, comments}`
- `%Input{must, typedefs, groupings, body, meta, comments}`
- `%Output{must, typedefs, groupings, body, meta, comments}`
- `%Notification{name, must, typedefs, groupings, body, status, description, reference, if_features, meta, comments}`

### Constraints

- `%Must{xpath, xpath_ast, error_message, error_app_tag, description, reference, meta, comments}`
- `%When{xpath, xpath_ast, description, reference, meta, comments}`
- `%Range{expression, error_message, error_app_tag, description, reference, meta, comments}`
- `%Length{expression, error_message, error_app_tag, description, reference, meta, comments}`
- `%Pattern{value, modifier, error_message, error_app_tag, description, reference, meta, comments}`

### Extension

- `%ExtensionDef{name, argument, status, description, reference, meta, comments}` — defining an extension keyword
- `%ExtensionUse{keyword, argument, sub_statements, meta, comments}` — using an extension (opaque)

### Protocols

`%Module{}` implements `Access` and `Enumerable` over its `body` field, same as ex_hcl's `%Document{}`.

## Resolver — Cross-Module Resolution

Operates on parsed `%Module{}` structs from the registry. Runs as an ordered pipeline:

### Phase 1: Import/Include Resolution

`ImportResolver` walks imports and includes, pulls corresponding parsed ASTs from the registry, builds a namespace map `%{prefix => %Module{}}`. Submodules are merged into their parent. Circular dependencies are detected and rejected.

### Phase 2: Type Resolution

`TypeResolver` follows typedef chains to their base built-in type. Cross-module typedefs are followed through the namespace map. The 19 built-in types (RFC 7950 Section 4.2.4) are terminals: `int8`, `int16`, `int32`, `int64`, `uint8`, `uint16`, `uint32`, `uint64`, `decimal64`, `string`, `boolean`, `enumeration`, `bits`, `binary`, `leafref`, `identityref`, `empty`, `union`, `instance-identifier`.

### Phase 3: Identity Resolution

`IdentityResolver` builds the identity inheritance DAG across all modules in scope. Identities can derive from multiple bases (YANG 1.1). `identityref` type references resolve against this graph.

### Phase 4: Grouping Expansion

`GroupingResolver` expands every `uses` statement inline, copying the grouping's body and applying `refine` statements. Nested groupings are expanded recursively. After this phase, no `%Uses{}` or `%Grouping{}` nodes remain.

### Phase 5: Augment Application

`AugmentResolver` resolves each augment's `target-node` schema path and inserts the augmented nodes at that location. Cross-module augments use the namespace map. `when` expressions are preserved.

### Phase 6: Deviation Application

`DeviationResolver` applies deviations: `not-supported` removes nodes, `add` inserts properties, `replace` overwrites, `delete` removes specific properties. Last phase because deviations are intentional overrides.

### Output

```elixir
{:ok, %ResolvedModule{
  module: %Module{},           # fully resolved, no uses/groupings remaining
  namespace_map: %{},          # prefix -> module
  identity_graph: %Graph{},    # DAG of identity inheritance
  diagnostics: []              # warnings accumulated during resolution
}}
```

Re-resolution is triggered when a dependency module is updated.

## Registry — Ecto-Backed Module Storage

### Ecto Schemas

**`yang_modules`** — one row per parsed module/revision:
- `id` (UUID)
- `name` (string, indexed)
- `revision` (date, indexed)
- `namespace` (string, unique)
- `yang_version` (string)
- `source` (text — original YANG source)
- `parsed_ast` (binary — `:erlang.term_to_binary` of unresolved `%Module{}`)
- `resolved_ast` (binary — resolved `%ResolvedModule{}`, nullable)
- `status` (enum — `:parsed`, `:resolved`, `:error`)
- `diagnostics` (binary — serialized diagnostic list)
- `inserted_at`, `updated_at`

Unique constraint on `{name, revision}`.

**`yang_dependencies`** — relationship graph:
- `id` (UUID)
- `source_module_id` (FK)
- `target_module_id` (FK)
- `type` (enum — `:import`, `:include`, `:augment`, `:deviation`, `:identity_base`, `:uses_grouping`)
- `target_node_path` (string, nullable)

**`yang_identities`** — denormalized identity graph:
- `id` (UUID)
- `module_id` (FK)
- `name` (string)
- `base_names` (array of strings)

### Behaviour

```elixir
defmodule ExYang.Registry do
  @callback store(Module.t(), source :: String.t()) :: {:ok, id} | {:error, term()}
  @callback fetch(name :: String.t(), revision :: Date.t() | nil) :: {:ok, Module.t()} | :error
  @callback resolve(name :: String.t(), revision :: Date.t() | nil) :: {:ok, ResolvedModule.t()} | {:error, diagnostics}
  @callback dependencies(name :: String.t(), revision :: Date.t() | nil) :: [dep]
  @callback dependents(name :: String.t(), revision :: Date.t() | nil) :: [dep]
  @callback search(query :: keyword()) :: [Module.t()]
  @callback delete(name :: String.t(), revision :: Date.t() | nil) :: :ok | :error
end
```

`dependents/2` drives re-resolution when a module is updated.

### Configuration

```elixir
config :ex_yang, ExYang.Registry,
  repo: MyApp.Repo
```

Migrations ship as `mix ex_yang.migrate` or embeddable migration module (Oban pattern).

## Encoder & Formatter

### Encoder (`ExYang.encode/1`) — Round-Trip Faithful

- Indentation/whitespace from `meta.whitespace`
- Comments emitted at recorded positions (leading, inline, floating)
- String quoting style preserved
- Concatenated strings re-emitted as fragments if original used `+`
- Unmodified nodes are byte-identical to source
- Programmatically created/modified nodes get default style: 2-space indent, double quotes

Operates on both unresolved and resolved trees.

### Formatter (`ExYang.format/1`) — Canonical Style

- 2-space indentation
- Double quotes for all strings
- Sub-statements ordered per RFC 7950 convention
- One blank line between top-level statements
- No blank lines within leaf/typedef/etc.
- 80-column target with `+` continuation for long strings

### Public API

```elixir
ExYang.parse(source)              # => {:ok, %Module{}}
ExYang.parse!(source)             # => %Module{} | raise
ExYang.encode(module)             # => {:ok, string}  (round-trip)
ExYang.format(module)             # => {:ok, string}  (canonical)
ExYang.resolve(module, registry)  # => {:ok, %ResolvedModule{}}
```

## XPath Subset Parser

Parses XPath 1.0 expressions used in `when` and `must` statements. Does not evaluate — parses and represents.

Handles:
- Path expressions (absolute and relative)
- Predicates
- Core YANG functions (`current()`, `derived-from()`, `derived-from-or-self()`, `deref()`, `re-match()`, `bit-is-set()`, `enum-value()`, `position()`, `count()`, etc.)
- Boolean, comparison, and arithmetic operators
- String/number literals
- Namespace prefixes

XPath source string is preserved verbatim for round-trip. Parsed AST stored alongside for consumer inspection:

```elixir
%Must{
  xpath: "derived-from-or-self(type, 'ianaift:ethernetCsmacd')",
  xpath_ast: {:call, :derived_from_or_self, [{:path, [:type]}, {:literal, "ianaift:ethernetCsmacd"}]},
  ...
}
```

Separate NimbleParsec grammar in `lib/ex_yang/xpath/xpath.ex`.

## Error Handling & Diagnostics

Unified `%Diagnostic{}` struct across all phases:

```elixir
%Diagnostic{
  severity: :error | :warning | :info,
  phase: :lexer | :grammar | :transform | :validation | :resolution,
  message: "missing mandatory sub-statement 'type' in leaf 'name'",
  file: "ietf-interfaces.yang",
  line: 42,
  column: 5,
  context: ["module ietf-interfaces", "container interfaces", "leaf name"]
}
```

Each phase accumulates diagnostics rather than failing on first error:
- **Lexer** — unterminated strings, invalid escapes, illegal characters
- **Grammar** — unexpected tokens, unclosed braces, malformed statements
- **Transform** — unknown non-extension keywords, argument type mismatches
- **Validation** — cardinality violations, illegal sub-statements, conflicting properties
- **Resolution** — missing imports, circular deps, invalid augment targets, unresolvable typedefs

Terminal formatting:

```
error[validation]: missing mandatory sub-statement 'type' in leaf 'name'
  --> ietf-interfaces.yang:42:5
  in: module ietf-interfaces > container interfaces > leaf name
```

## Testing Strategy

### Fixtures

Real YANG modules from IETF RFCs:
- `ietf-yang-types@2013-07-15.yang` — typedefs
- `ietf-inet-types@2013-07-15.yang` — import chains
- `ietf-interfaces@2018-02-20.yang` — containers, lists, leafrefs, features
- `ietf-ip@2018-02-20.yang` — cross-module augmentation
- `ietf-routing@2018-03-13.yang` — identities, augments, when expressions
- `ietf-yang-library@2019-01-04.yang` — exercises most statement types
- `ietf-netconf-acm@2018-02-14.yang` — deviations, complex constraints

### Test Layers

- **Lexer** — token stream assertions for quoting, escaping, concatenation, comments
- **Grammar** — generic tree structure for individual and nested statements
- **Transform** — typed struct output per statement type, extension handling
- **Validation** — cardinality enforcement, illegal combinations, diagnostic quality
- **Resolver** — each phase independently plus end-to-end multi-module resolution
- **Encoder** — round-trip: `parse(source) |> encode() == source` for all fixtures
- **Formatter** — canonical output for known inputs
- **XPath** — parse and re-emit for expressions from RFC fixtures
- **Registry** — store/fetch/resolve/dependency queries (tagged for SQLite and Postgres)

### Key Invariant

`parse(encode(parse(source))) == parse(source)` — parse-encode-parse produces the same AST. Byte-identical round-trip on unmodified modules is the stretch goal.
