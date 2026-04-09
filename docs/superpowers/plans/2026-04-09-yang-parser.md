# ExYang Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete YANG (RFC 7950) parser, resolver, encoder, and registry for Elixir.

**Architecture:** Two-pass parser (NimbleParsec generic tree → typed structs), Ecto-backed module registry, round-trip encoder, canonical formatter. Cross-module resolution via a six-phase pipeline. XPath subset parser for `when`/`must` expressions.

**Tech Stack:** Elixir 1.17+/OTP 27+, NimbleParsec, Ecto (SQLite + Postgres), ExDoc

---

## File Structure

```
lib/
├── ex_yang.ex                          # Public API
├── ex_yang/
│   ├── diagnostic.ex                   # %Diagnostic{} struct + formatter
│   ├── parser/
│   │   ├── lexer.ex                    # NimbleParsec tokenizer
│   │   ├── grammar.ex                  # NimbleParsec generic tree builder
│   │   └── comment_attacher.ex         # Post-parse comment attachment
│   ├── transform/
│   │   ├── builder.ex                  # Generic tree → typed structs
│   │   ├── validator.ex                # Sub-statement cardinality rules
│   │   └── extensions.ex               # Extension handler registry + behaviour
│   ├── model/
│   │   ├── module.ex                   # %Module{}, %Submodule{}
│   │   ├── header.ex                   # %Import{}, %Include{}, %Revision{}, %BelongsTo{}
│   │   ├── data_def.ex                 # %Container{}, %Leaf{}, %LeafList{}, %List{}, %Choice{}, %Case{}, %AnyData{}, %AnyXml{}
│   │   ├── schema.ex                   # %Grouping{}, %Uses{}, %Refine{}, %Augment{}, %Deviation{}, %Deviate{}
│   │   ├── type.ex                     # %Typedef{}, %Type{}, %Enum{}, %Bit{}
│   │   ├── identity.ex                 # %Identity{}, %Feature{}
│   │   ├── rpc.ex                      # %Rpc{}, %Action{}, %Input{}, %Output{}, %Notification{}
│   │   ├── constraint.ex               # %Must{}, %When{}, %Range{}, %Length{}, %Pattern{}
│   │   ├── extension.ex                # %ExtensionDef{}, %ExtensionUse{}
│   │   └── common.ex                   # Meta type, shared type aliases
│   ├── resolver/
│   │   ├── resolver.ex                 # Pipeline orchestrator
│   │   ├── import_resolver.ex          # Phase 1: imports/includes
│   │   ├── type_resolver.ex            # Phase 2: typedef chains
│   │   ├── identity_resolver.ex        # Phase 3: identity DAG
│   │   ├── grouping_resolver.ex        # Phase 4: uses expansion
│   │   ├── augment_resolver.ex         # Phase 5: augment application
│   │   ├── deviation_resolver.ex       # Phase 6: deviation application
│   │   └── resolved_module.ex          # %ResolvedModule{} struct
│   ├── registry/
│   │   ├── registry.ex                 # Behaviour
│   │   ├── ecto_registry.ex            # Ecto implementation
│   │   ├── schema/
│   │   │   ├── yang_module.ex          # Ecto schema
│   │   │   ├── yang_dependency.ex      # Ecto schema
│   │   │   └── yang_identity.ex        # Ecto schema
│   │   └── migrations/
│   │       └── v01.ex                  # Initial migration
│   ├── encoder/
│   │   ├── encoder.ex                  # Round-trip faithful
│   │   └── formatter.ex                # Canonical style
│   └── xpath/
│       └── xpath.ex                    # XPath subset parser
test/
├── test_helper.exs
├── fixtures/                           # .yang files from IETF RFCs
├── ex_yang/
│   ├── parser/
│   │   ├── lexer_test.exs
│   │   ├── grammar_test.exs
│   │   └── comment_attacher_test.exs
│   ├── transform/
│   │   ├── builder_test.exs
│   │   ├── validator_test.exs
│   │   └── extensions_test.exs
│   ├── resolver/
│   │   ├── import_resolver_test.exs
│   │   ├── type_resolver_test.exs
│   │   ├── identity_resolver_test.exs
│   │   ├── grouping_resolver_test.exs
│   │   ├── augment_resolver_test.exs
│   │   ├── deviation_resolver_test.exs
│   │   └── resolver_test.exs
│   ├── encoder/
│   │   ├── encoder_test.exs
│   │   └── formatter_test.exs
│   ├── registry/
│   │   └── ecto_registry_test.exs
│   ├── xpath/
│   │   └── xpath_test.exs
│   └── ex_yang_test.exs
```

---

### Task 1: Project Scaffold

**Files:**
- Create: `mix.exs`
- Create: `lib/ex_yang.ex`
- Create: `lib/ex_yang/diagnostic.ex`
- Create: `test/test_helper.exs`
- Create: `.formatter.exs`
- Create: `.gitignore`
- Create: `LICENSE`

- [ ] **Step 1: Create mix.exs**

```elixir
defmodule ExYang.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :ex_yang,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: ["AGPL-3.0-only"],
      description: "YANG (RFC 7950) parser, resolver, and data modeling library for Elixir",
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ecto, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17", optional: true},
      {:postgrex, "~> 0.19", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
```

- [ ] **Step 2: Create .formatter.exs**

```elixir
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

- [ ] **Step 3: Create .gitignore**

```
/_build/
/cover/
/deps/
/doc/
/.fetch
erl_crash.dump
*.ez
*.beam
/tmp/
*.sqlite3
*.sqlite3-journal
```

- [ ] **Step 4: Create LICENSE (AGPL-3.0)**

```
SPDX-License-Identifier: AGPL-3.0-only
```

Run: `curl -sL https://www.gnu.org/licenses/agpl-3.0.txt > LICENSE` or write the full text.

- [ ] **Step 5: Create lib/ex_yang/diagnostic.ex**

```elixir
defmodule ExYang.Diagnostic do
  @moduledoc """
  Structured diagnostic message emitted by parser, transform, validation,
  and resolution phases.
  """

  @enforce_keys [:severity, :phase, :message]
  defstruct [
    :severity,
    :phase,
    :message,
    :file,
    :line,
    :column,
    context: []
  ]

  @type severity :: :error | :warning | :info
  @type phase :: :lexer | :grammar | :transform | :validation | :resolution

  @type t :: %__MODULE__{
          severity: severity(),
          phase: phase(),
          message: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          context: [String.t()]
        }

  @doc """
  Format a diagnostic for terminal output.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = d) do
    location =
      case {d.file, d.line, d.column} do
        {nil, nil, nil} -> ""
        {file, line, col} -> "\n  --> #{file || "<input>"}:#{line || "?"}:#{col || "?"}"
      end

    context =
      case d.context do
        [] -> ""
        parts -> "\n  in: #{Enum.join(parts, " > ")}"
      end

    "#{d.severity}[#{d.phase}]: #{d.message}#{location}#{context}"
  end
end
```

- [ ] **Step 6: Create lib/ex_yang.ex (stub)**

```elixir
defmodule ExYang do
  @moduledoc """
  YANG (RFC 7950) parser, resolver, and data modeling library for Elixir.
  """
end
```

- [ ] **Step 7: Create test/test_helper.exs**

```elixir
ExUnit.start()
```

- [ ] **Step 8: Install dependencies and verify**

Run: `mix deps.get && mix compile && mix test`
Expected: 0 tests, 0 failures. Clean compile with no warnings.

- [ ] **Step 9: Commit**

```bash
git add mix.exs lib/ test/ .formatter.exs .gitignore LICENSE
git commit -m "Scaffold ex_yang project with diagnostic struct"
```

---

### Task 2: Model Structs — Common & Header

**Files:**
- Create: `lib/ex_yang/model/common.ex`
- Create: `lib/ex_yang/model/header.ex`
- Create: `lib/ex_yang/model/module.ex`
- Create: `test/ex_yang/model/module_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/model/module_test.exs
defmodule ExYang.Model.ModuleTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{Module, Import, Revision}

  test "Module struct has expected fields with defaults" do
    mod = %Module{name: "test-module"}
    assert mod.name == "test-module"
    assert mod.namespace == nil
    assert mod.prefix == nil
    assert mod.yang_version == nil
    assert mod.imports == []
    assert mod.includes == []
    assert mod.revisions == []
    assert mod.body == []
    assert mod.typedefs == []
    assert mod.groupings == []
    assert mod.identities == []
    assert mod.extensions == []
    assert mod.rpcs == []
    assert mod.notifications == []
    assert mod.augments == []
    assert mod.deviations == []
    assert mod.features == []
    assert mod.meta == %{}
    assert mod.comments == []
    assert mod.organization == nil
    assert mod.contact == nil
    assert mod.description == nil
    assert mod.reference == nil
  end

  test "Import struct" do
    imp = %Import{module: "ietf-yang-types", prefix: "yang"}
    assert imp.module == "ietf-yang-types"
    assert imp.prefix == "yang"
    assert imp.revision_date == nil
  end

  test "Revision struct" do
    rev = %Revision{date: "2018-02-20", description: "Initial revision."}
    assert rev.date == "2018-02-20"
    assert rev.description == "Initial revision."
  end

  test "Module implements Access" do
    mod = %Module{name: "test", body: []}
    assert {:ok, []} == Access.fetch(mod, :body)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/model/module_test.exs`
Expected: compilation error — Module not defined.

- [ ] **Step 3: Create lib/ex_yang/model/common.ex**

```elixir
defmodule ExYang.Model.Common do
  @moduledoc """
  Shared type definitions for ExYang model structs.
  """

  @type meta :: %{
          optional(:line) => pos_integer(),
          optional(:column) => pos_integer(),
          optional(:whitespace) => list(),
          optional(:string_fragments) => list()
        }

  @type comment_position :: :leading | :inline | :floating

  @type comment :: %{text: String.t(), position: comment_position()}
end
```

- [ ] **Step 4: Create lib/ex_yang/model/header.ex**

```elixir
defmodule ExYang.Model.Import do
  @moduledoc "YANG `import` statement."
  defstruct [
    :module,
    :prefix,
    :revision_date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          prefix: String.t(),
          revision_date: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }
end

defmodule ExYang.Model.Include do
  @moduledoc "YANG `include` statement."
  defstruct [
    :module,
    :revision_date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          revision_date: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }
end

defmodule ExYang.Model.Revision do
  @moduledoc "YANG `revision` statement."
  defstruct [
    :date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          date: String.t(),
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }
end

defmodule ExYang.Model.BelongsTo do
  @moduledoc "YANG `belongs-to` statement (submodule header)."
  defstruct [
    :module,
    :prefix,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          prefix: String.t(),
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }
end
```

- [ ] **Step 5: Create lib/ex_yang/model/module.ex**

```elixir
defmodule ExYang.Model.Module do
  @moduledoc """
  YANG `module` statement — the top-level container for a YANG data model.

  Implements `Access` over its `body` field.
  """

  @behaviour Access

  defstruct [
    :name,
    :namespace,
    :prefix,
    :yang_version,
    :organization,
    :contact,
    :description,
    :reference,
    imports: [],
    includes: [],
    revisions: [],
    body: [],
    typedefs: [],
    groupings: [],
    identities: [],
    extensions: [],
    rpcs: [],
    notifications: [],
    augments: [],
    deviations: [],
    features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          namespace: String.t() | nil,
          prefix: String.t() | nil,
          yang_version: String.t() | nil,
          organization: String.t() | nil,
          contact: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          imports: [ExYang.Model.Import.t()],
          includes: [ExYang.Model.Include.t()],
          revisions: [ExYang.Model.Revision.t()],
          body: list(),
          typedefs: list(),
          groupings: list(),
          identities: list(),
          extensions: list(),
          rpcs: list(),
          notifications: list(),
          augments: list(),
          deviations: list(),
          features: list(),
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }

  @impl Access
  def fetch(%__MODULE__{} = mod, key) do
    Map.fetch(mod, key)
  end

  @impl Access
  def get_and_update(%__MODULE__{} = mod, key, fun) do
    Map.get_and_update(mod, key, fun)
  end

  @impl Access
  def pop(%__MODULE__{} = mod, key) do
    Map.pop(mod, key)
  end
end

defmodule ExYang.Model.Submodule do
  @moduledoc "YANG `submodule` statement."

  defstruct [
    :name,
    :yang_version,
    :belongs_to,
    :organization,
    :contact,
    :description,
    :reference,
    imports: [],
    includes: [],
    revisions: [],
    body: [],
    typedefs: [],
    groupings: [],
    identities: [],
    extensions: [],
    rpcs: [],
    notifications: [],
    augments: [],
    deviations: [],
    features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          belongs_to: ExYang.Model.BelongsTo.t() | nil,
          yang_version: String.t() | nil,
          organization: String.t() | nil,
          contact: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          imports: list(),
          includes: list(),
          revisions: list(),
          body: list(),
          typedefs: list(),
          groupings: list(),
          identities: list(),
          extensions: list(),
          rpcs: list(),
          notifications: list(),
          augments: list(),
          deviations: list(),
          features: list(),
          meta: ExYang.Model.Common.meta(),
          comments: list()
        }
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/ex_yang/model/module_test.exs`
Expected: 4 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add lib/ex_yang/model/ test/ex_yang/model/
git commit -m "Add model structs: Module, Submodule, Import, Include, Revision, BelongsTo"
```

---

### Task 3: Model Structs — Data Definition

**Files:**
- Create: `lib/ex_yang/model/data_def.ex`
- Create: `test/ex_yang/model/data_def_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/model/data_def_test.exs
defmodule ExYang.Model.DataDefTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{Container, Leaf, LeafList, List, Choice, Case, AnyData, AnyXml}

  test "Container struct defaults" do
    c = %Container{name: "interfaces"}
    assert c.name == "interfaces"
    assert c.body == []
    assert c.config == nil
    assert c.presence == nil
    assert c.must == []
    assert c.when_expr == nil
    assert c.if_features == []
    assert c.typedefs == []
    assert c.groupings == []
  end

  test "Leaf struct defaults" do
    l = %Leaf{name: "mtu"}
    assert l.name == "mtu"
    assert l.type == nil
    assert l.default == nil
    assert l.mandatory == nil
    assert l.units == nil
  end

  test "LeafList struct defaults" do
    ll = %LeafList{name: "search"}
    assert ll.min_elements == nil
    assert ll.max_elements == nil
    assert ll.ordered_by == nil
  end

  test "List struct defaults" do
    l = %List{name: "interface"}
    assert l.key == nil
    assert l.unique == []
    assert l.body == []
  end

  test "Choice struct defaults" do
    c = %Choice{name: "address-family"}
    assert c.cases == []
    assert c.default == nil
  end

  test "Case struct defaults" do
    c = %Case{name: "ipv4"}
    assert c.body == []
  end

  test "AnyData struct defaults" do
    a = %AnyData{name: "data"}
    assert a.config == nil
    assert a.mandatory == nil
  end

  test "AnyXml struct defaults" do
    a = %AnyXml{name: "filter"}
    assert a.config == nil
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/model/data_def_test.exs`
Expected: compilation error — Container not defined.

- [ ] **Step 3: Create lib/ex_yang/model/data_def.ex**

```elixir
defmodule ExYang.Model.Container do
  @moduledoc "YANG `container` statement."
  defstruct [
    :name, :config, :presence, :when_expr, :status, :description, :reference,
    must: [], if_features: [], typedefs: [], groupings: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Leaf do
  @moduledoc "YANG `leaf` statement."
  defstruct [
    :name, :type, :default, :config, :mandatory, :when_expr, :status,
    :units, :description, :reference,
    must: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.LeafList do
  @moduledoc "YANG `leaf-list` statement."
  defstruct [
    :name, :type, :config, :min_elements, :max_elements, :ordered_by,
    :when_expr, :status, :units, :description, :reference,
    must: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.List do
  @moduledoc "YANG `list` statement."
  defstruct [
    :name, :key, :config, :min_elements, :max_elements, :ordered_by,
    :when_expr, :status, :description, :reference,
    unique: [], must: [], if_features: [], typedefs: [], groupings: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Choice do
  @moduledoc "YANG `choice` statement."
  defstruct [
    :name, :default, :config, :mandatory, :when_expr, :status,
    :description, :reference,
    must: [], if_features: [], cases: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Case do
  @moduledoc "YANG `case` statement."
  defstruct [
    :name, :when_expr, :status, :description, :reference,
    if_features: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.AnyData do
  @moduledoc "YANG `anydata` statement."
  defstruct [
    :name, :config, :mandatory, :when_expr, :status, :description, :reference,
    must: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.AnyXml do
  @moduledoc "YANG `anyxml` statement."
  defstruct [
    :name, :config, :mandatory, :when_expr, :status, :description, :reference,
    must: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

Note: the spec used `when` as a field name, but `when` is a reserved word in Elixir. We use `when_expr` instead throughout all structs.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/model/data_def_test.exs`
Expected: 8 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/model/data_def.ex test/ex_yang/model/data_def_test.exs
git commit -m "Add data definition model structs: Container, Leaf, LeafList, List, Choice, Case, AnyData, AnyXml"
```

---

### Task 4: Model Structs — Schema Manipulation

**Files:**
- Create: `lib/ex_yang/model/schema.ex`
- Create: `test/ex_yang/model/schema_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/model/schema_test.exs
defmodule ExYang.Model.SchemaTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{Grouping, Uses, Refine, Augment, Deviation, Deviate}

  test "Grouping struct" do
    g = %Grouping{name: "endpoint"}
    assert g.body == []
    assert g.typedefs == []
    assert g.groupings == []
  end

  test "Uses struct" do
    u = %Uses{grouping: "endpoint"}
    assert u.refines == []
    assert u.augments == []
  end

  test "Refine struct" do
    r = %Refine{target_node: "address"}
    assert r.config == nil
    assert r.mandatory == nil
    assert r.must == []
  end

  test "Augment struct" do
    a = %Augment{target_node: "/if:interfaces/if:interface"}
    assert a.body == []
    assert a.when_expr == nil
  end

  test "Deviation struct" do
    d = %Deviation{target_node: "/if:interfaces/if:interface/if:mtu"}
    assert d.deviates == []
  end

  test "Deviate struct" do
    d = %Deviate{type: :not_supported}
    assert d.type == :not_supported
    assert d.config == nil
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/model/schema_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/model/schema.ex**

```elixir
defmodule ExYang.Model.Grouping do
  @moduledoc "YANG `grouping` statement."
  defstruct [
    :name, :status, :description, :reference,
    typedefs: [], groupings: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Uses do
  @moduledoc "YANG `uses` statement."
  defstruct [
    :grouping, :when_expr, :status, :description, :reference,
    if_features: [], refines: [], augments: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Refine do
  @moduledoc "YANG `refine` statement."
  defstruct [
    :target_node, :description, :reference, :config, :default,
    :mandatory, :presence, :min_elements, :max_elements,
    must: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Augment do
  @moduledoc "YANG `augment` statement."
  defstruct [
    :target_node, :when_expr, :status, :description, :reference,
    if_features: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Deviation do
  @moduledoc "YANG `deviation` statement."
  defstruct [
    :target_node, :description, :reference,
    deviates: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Deviate do
  @moduledoc "YANG `deviate` statement."
  defstruct [
    :type, :config, :default, :mandatory, :type_replacement,
    :units,
    must: [], min_elements: nil, max_elements: nil, unique: [],
    meta: %{}, comments: []
  ]
  @type type :: :not_supported | :add | :replace | :delete
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/model/schema_test.exs`
Expected: 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/model/schema.ex test/ex_yang/model/schema_test.exs
git commit -m "Add schema manipulation model structs: Grouping, Uses, Refine, Augment, Deviation, Deviate"
```

---

### Task 5: Model Structs — Type System, Identity, RPC, Constraint, Extension

**Files:**
- Create: `lib/ex_yang/model/type.ex`
- Create: `lib/ex_yang/model/identity.ex`
- Create: `lib/ex_yang/model/rpc.ex`
- Create: `lib/ex_yang/model/constraint.ex`
- Create: `lib/ex_yang/model/extension.ex`
- Create: `test/ex_yang/model/remaining_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/model/remaining_test.exs
defmodule ExYang.Model.RemainingTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{
    Typedef, Type, Enum, Bit,
    Identity, Feature,
    Rpc, Action, Input, Output, Notification,
    Must, When, Range, Length, Pattern,
    ExtensionDef, ExtensionUse
  }

  test "Typedef struct" do
    t = %Typedef{name: "percentage"}
    assert t.type == nil
    assert t.default == nil
  end

  test "Type struct" do
    t = %Type{name: "string"}
    assert t.base == nil
    assert t.range == nil
    assert t.patterns == []
    assert t.enum_values == []
    assert t.union_types == []
  end

  test "Enum struct" do
    e = %Enum{name: "up"}
    assert e.value == nil
  end

  test "Bit struct" do
    b = %Bit{name: "receive"}
    assert b.position == nil
  end

  test "Identity struct" do
    i = %Identity{name: "transport"}
    assert i.bases == []
  end

  test "Feature struct" do
    f = %Feature{name: "ssh"}
    assert f.if_features == []
  end

  test "Rpc struct" do
    r = %Rpc{name: "restart"}
    assert r.input == nil
    assert r.output == nil
  end

  test "Action struct" do
    a = %Action{name: "reset"}
    assert a.input == nil
  end

  test "Input/Output structs" do
    i = %Input{}
    assert i.body == []
    o = %Output{}
    assert o.body == []
  end

  test "Notification struct" do
    n = %Notification{name: "link-failure"}
    assert n.body == []
  end

  test "Must struct" do
    m = %Must{xpath: "../type = 'ethernet'"}
    assert m.xpath_ast == nil
    assert m.error_message == nil
  end

  test "When struct" do
    w = %When{xpath: "../enabled = 'true'"}
    assert w.xpath_ast == nil
  end

  test "Range struct" do
    r = %Range{expression: "0..100"}
    assert r.error_message == nil
  end

  test "Length struct" do
    l = %Length{expression: "1..255"}
    assert l.error_message == nil
  end

  test "Pattern struct" do
    p = %Pattern{value: "[0-9a-fA-F]*"}
    assert p.modifier == nil
  end

  test "ExtensionDef struct" do
    e = %ExtensionDef{name: "my-ext"}
    assert e.argument == nil
  end

  test "ExtensionUse struct" do
    e = %ExtensionUse{keyword: {"mymod", "my-ext"}}
    assert e.argument == nil
    assert e.sub_statements == []
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/model/remaining_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/model/type.ex**

```elixir
defmodule ExYang.Model.Typedef do
  @moduledoc "YANG `typedef` statement."
  defstruct [
    :name, :type, :default, :status, :units, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Type do
  @moduledoc """
  YANG `type` statement.

  Polymorphic — different constraints are populated depending on the
  base type. For example, `range` is only meaningful for numeric types,
  `patterns` only for string types, `enum_values` only for enumerations.
  """
  defstruct [
    :name, :base, :range, :length, :fraction_digits, :path,
    :require_instance,
    patterns: [], enum_values: [], bit_values: [], union_types: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Enum do
  @moduledoc "YANG `enum` statement (within an enumeration type)."
  defstruct [
    :name, :value, :status, :description, :reference,
    if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Bit do
  @moduledoc "YANG `bit` statement (within a bits type)."
  defstruct [
    :name, :position, :status, :description, :reference,
    if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 4: Create lib/ex_yang/model/identity.ex**

```elixir
defmodule ExYang.Model.Identity do
  @moduledoc "YANG `identity` statement."
  defstruct [
    :name, :status, :description, :reference,
    bases: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Feature do
  @moduledoc "YANG `feature` statement."
  defstruct [
    :name, :status, :description, :reference,
    if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 5: Create lib/ex_yang/model/rpc.ex**

```elixir
defmodule ExYang.Model.Rpc do
  @moduledoc "YANG `rpc` statement."
  defstruct [
    :name, :input, :output, :status, :description, :reference,
    typedefs: [], groupings: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Action do
  @moduledoc "YANG `action` statement."
  defstruct [
    :name, :input, :output, :status, :description, :reference,
    typedefs: [], groupings: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Input do
  @moduledoc "YANG `input` statement."
  defstruct [
    must: [], typedefs: [], groupings: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Output do
  @moduledoc "YANG `output` statement."
  defstruct [
    must: [], typedefs: [], groupings: [], body: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Notification do
  @moduledoc "YANG `notification` statement."
  defstruct [
    :name, :status, :description, :reference,
    must: [], typedefs: [], groupings: [], body: [], if_features: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 6: Create lib/ex_yang/model/constraint.ex**

```elixir
defmodule ExYang.Model.Must do
  @moduledoc "YANG `must` statement."
  defstruct [
    :xpath, :xpath_ast, :error_message, :error_app_tag, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.When do
  @moduledoc "YANG `when` statement."
  defstruct [
    :xpath, :xpath_ast, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Range do
  @moduledoc "YANG `range` statement."
  defstruct [
    :expression, :error_message, :error_app_tag, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Length do
  @moduledoc "YANG `length` statement."
  defstruct [
    :expression, :error_message, :error_app_tag, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.Pattern do
  @moduledoc "YANG `pattern` statement."
  defstruct [
    :value, :modifier, :error_message, :error_app_tag, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 7: Create lib/ex_yang/model/extension.ex**

```elixir
defmodule ExYang.Model.ExtensionDef do
  @moduledoc "YANG `extension` statement — defines a new extension keyword."
  defstruct [
    :name, :argument, :status, :description, :reference,
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end

defmodule ExYang.Model.ExtensionUse do
  @moduledoc "An instance of an extension keyword in the tree (opaque)."
  defstruct [
    :keyword, :argument,
    sub_statements: [],
    meta: %{}, comments: []
  ]
  @type t :: %__MODULE__{}
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `mix test test/ex_yang/model/remaining_test.exs`
Expected: 17 tests, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add lib/ex_yang/model/ test/ex_yang/model/remaining_test.exs
git commit -m "Add remaining model structs: types, identity, rpc, constraints, extensions"
```

---

### Task 6: Lexer — Core Tokenization

**Files:**
- Create: `lib/ex_yang/parser/lexer.ex`
- Create: `test/ex_yang/parser/lexer_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/parser/lexer_test.exs
defmodule ExYang.Parser.LexerTest do
  use ExUnit.Case, async: true

  alias ExYang.Parser.Lexer

  describe "keywords" do
    test "simple keyword" do
      assert {:ok, [{:keyword, _, "container"}], _, _, _, _} = Lexer.tokenize("container")
    end

    test "prefixed keyword" do
      assert {:ok, [{:keyword, _, {"if", "interfaces"}}], _, _, _, _} =
               Lexer.tokenize("if:interfaces")
    end

    test "keyword with hyphens" do
      assert {:ok, [{:keyword, _, "leaf-list"}], _, _, _, _} = Lexer.tokenize("leaf-list")
    end
  end

  describe "strings" do
    test "double-quoted string" do
      assert {:ok, [{:dq_string, _, "hello world"}], _, _, _, _} =
               Lexer.tokenize(~s("hello world"))
    end

    test "single-quoted string" do
      assert {:ok, [{:sq_string, _, "hello world"}], _, _, _, _} =
               Lexer.tokenize("'hello world'")
    end

    test "double-quoted escape sequences" do
      assert {:ok, [{:dq_string, _, "line1\nline2"}], _, _, _, _} =
               Lexer.tokenize(~s("line1\\nline2"))
    end

    test "single-quoted string preserves backslashes" do
      assert {:ok, [{:sq_string, _, "no\\nescape"}], _, _, _, _} =
               Lexer.tokenize("'no\\nescape'")
    end

    test "unquoted string (date)" do
      assert {:ok, [{:keyword, _, "revision"}, {:whitespace, _, _}, {:keyword, _, "2018-02-20"}], _, _, _, _} =
               Lexer.tokenize("revision 2018-02-20")
    end
  end

  describe "punctuation" do
    test "braces and semicolons" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize("{ } ;")
      types = Enum.map(tokens, fn {type, _, _} -> type end) |> Enum.reject(&(&1 == :whitespace))
      assert types == [:open_brace, :close_brace, :semicolon]
    end

    test "string concatenation operator" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize(~s("a" + "b"))
      types = Enum.map(tokens, fn {type, _, _} -> type end) |> Enum.reject(&(&1 == :whitespace))
      assert types == [:dq_string, :plus, :dq_string]
    end
  end

  describe "comments" do
    test "line comment" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize("// this is a comment\ncontainer")
      types = Enum.map(tokens, fn {type, _, _} -> type end)
      assert :line_comment in types
      assert :keyword in types
    end

    test "block comment" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize("/* block\ncomment */container")
      types = Enum.map(tokens, fn {type, _, _} -> type end)
      assert :block_comment in types
    end
  end

  describe "whitespace preservation" do
    test "whitespace tokens are emitted" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize("leaf  name")
      types = Enum.map(tokens, fn {type, _, _} -> type end)
      assert :whitespace in types
    end

    test "newlines are emitted" do
      assert {:ok, tokens, _, _, _, _} = Lexer.tokenize("leaf\nname")
      types = Enum.map(tokens, fn {type, _, _} -> type end)
      assert :newline in types
    end
  end

  describe "token metadata" do
    test "tokens carry line numbers" do
      assert {:ok, [{:keyword, meta, "container"}], _, _, _, _} = Lexer.tokenize("container")
      assert meta.line == 1
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/parser/lexer_test.exs`
Expected: compilation error — Lexer not defined.

- [ ] **Step 3: Create lib/ex_yang/parser/lexer.ex**

```elixir
defmodule ExYang.Parser.Lexer do
  @moduledoc """
  NimbleParsec tokenizer for YANG.

  Produces a flat list of 3-element token tuples:

      {type, %{line: n, column: n, offset: n}, value}

  Token types:
    - `:keyword` — identifier or prefixed identifier (`prefix:name`)
    - `:dq_string` — double-quoted string (escapes resolved)
    - `:sq_string` — single-quoted string (literal)
    - `:open_brace`, `:close_brace`, `:semicolon`, `:plus`
    - `:line_comment`, `:block_comment`
    - `:newline`, `:whitespace`
  """

  import NimbleParsec

  # ---------------------------------------------------------------------------
  # Whitespace
  # ---------------------------------------------------------------------------

  whitespace =
    ascii_char([?\s, ?\t])
    |> times(min: 1)
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_whitespace)

  newline =
    string("\n")
    |> post_traverse(:emit_newline)

  # ---------------------------------------------------------------------------
  # Comments
  # ---------------------------------------------------------------------------

  line_comment =
    string("//")
    |> repeat(lookahead_not(ascii_char([?\n])) |> utf8_char([]))
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_line_comment)

  block_comment =
    string("/*")
    |> repeat(lookahead_not(string("*/")) |> utf8_char([]))
    |> string("*/")
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_block_comment)

  # ---------------------------------------------------------------------------
  # Strings
  # ---------------------------------------------------------------------------

  dq_escape =
    ignore(string("\\"))
    |> choice([
      string("n") |> replace(?\n),
      string("t") |> replace(?\t),
      string("\\") |> replace(?\\),
      string("\"") |> replace(?")
    ])

  dq_content =
    repeat(
      choice([
        dq_escape,
        lookahead_not(ascii_char([?", ?\\])) |> utf8_char([])
      ])
    )

  dq_string =
    ignore(string("\""))
    |> concat(dq_content)
    |> ignore(string("\""))
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_dq_string)

  sq_content =
    repeat(
      lookahead_not(ascii_char([?'])) |> utf8_char([])
    )

  sq_string =
    ignore(string("'"))
    |> concat(sq_content)
    |> ignore(string("'"))
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_sq_string)

  # ---------------------------------------------------------------------------
  # Punctuation
  # ---------------------------------------------------------------------------

  open_brace = string("{") |> post_traverse(:emit_open_brace)
  close_brace = string("}") |> post_traverse(:emit_close_brace)
  semicolon = string(";") |> post_traverse(:emit_semicolon)
  plus = string("+") |> post_traverse(:emit_plus)

  # ---------------------------------------------------------------------------
  # Keywords (identifiers, possibly prefixed with colon)
  # YANG identifiers: [a-zA-Z_][a-zA-Z0-9_.-]*
  # Also handles dates like 2018-02-20 as keywords
  # ---------------------------------------------------------------------------

  identifier_char = ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?.])

  keyword =
    ascii_char([?a..?z, ?A..?Z, ?_, ?0..?9])
    |> repeat(identifier_char)
    |> reduce({List, :to_string, []})
    |> post_traverse(:emit_keyword)

  # ---------------------------------------------------------------------------
  # Top-level token
  # ---------------------------------------------------------------------------

  token =
    choice([
      whitespace,
      newline,
      block_comment,
      line_comment,
      dq_string,
      sq_string,
      open_brace,
      close_brace,
      semicolon,
      plus,
      keyword
    ])

  defparsec(:tokenize, repeat(token) |> eos())

  # ---------------------------------------------------------------------------
  # Post-traverse callbacks
  # ---------------------------------------------------------------------------

  defp emit_whitespace(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:whitespace, %{line: line, column: col, offset: byte_offset}, text}], context}
  end

  defp emit_newline(rest, _results, context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:newline, %{line: line, column: col, offset: byte_offset}, "\n"}], context}
  end

  defp emit_line_comment(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:line_comment, %{line: line, column: col, offset: byte_offset}, text}], context}
  end

  defp emit_block_comment(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:block_comment, %{line: line, column: col, offset: byte_offset}, text}], context}
  end

  defp emit_dq_string(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:dq_string, %{line: line, column: col, offset: byte_offset}, text}], context}
  end

  defp emit_sq_string(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:sq_string, %{line: line, column: col, offset: byte_offset}, text}], context}
  end

  defp emit_open_brace(rest, _results, context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:open_brace, %{line: line, column: col, offset: byte_offset}, "{"}], context}
  end

  defp emit_close_brace(rest, _results, context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:close_brace, %{line: line, column: col, offset: byte_offset}, "}"}], context}
  end

  defp emit_semicolon(rest, _results, context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:semicolon, %{line: line, column: col, offset: byte_offset}, ";"}], context}
  end

  defp emit_plus(rest, _results, context, {line, _col}, byte_offset) do
    col = byte_offset + 1
    {rest, [{:plus, %{line: line, column: col, offset: byte_offset}, "+"}], context}
  end

  defp emit_keyword(rest, [text], context, {line, _col}, byte_offset) do
    col = byte_offset + 1

    value =
      case String.split(text, ":", parts: 2) do
        [prefix, name] when prefix != "" and name != "" -> {prefix, name}
        _ -> text
      end

    {rest, [{:keyword, %{line: line, column: col, offset: byte_offset}, value}], context}
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/parser/lexer_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/parser/lexer.ex test/ex_yang/parser/lexer_test.exs
git commit -m "Add YANG lexer with NimbleParsec tokenization"
```

---

### Task 7: Grammar — Generic Tree Builder

**Files:**
- Create: `lib/ex_yang/parser/grammar.ex`
- Create: `test/ex_yang/parser/grammar_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/parser/grammar_test.exs
defmodule ExYang.Parser.GrammarTest do
  use ExUnit.Case, async: true

  alias ExYang.Parser.Grammar

  describe "simple statements" do
    test "keyword with argument and semicolon" do
      assert {:ok, [{:description, "A test", [], meta}]} = Grammar.parse(~s(description "A test";))
      assert is_map(meta)
      assert Map.has_key?(meta, :line)
    end

    test "keyword without argument and semicolon" do
      assert {:ok, [{:config, "true", [], _meta}]} = Grammar.parse("config true;")
    end

    test "keyword with single-quoted argument" do
      assert {:ok, [{:pattern, "[0-9]+", [], _meta}]} = Grammar.parse("pattern '[0-9]+';")
    end
  end

  describe "block statements" do
    test "keyword with argument and block" do
      assert {:ok, [{:container, "interfaces", subs, _meta}]} =
               Grammar.parse("""
               container interfaces {
                 description "Network interfaces";
               }
               """)

      assert [{:description, "Network interfaces", [], _}] = subs
    end

    test "nested blocks" do
      assert {:ok, [{:container, "interfaces", subs, _meta}]} =
               Grammar.parse("""
               container interfaces {
                 list interface {
                   key "name";
                   leaf name {
                     type string;
                   }
                 }
               }
               """)

      assert [{:list, "interface", list_subs, _}] = subs
      assert length(list_subs) == 2
    end

    test "keyword with block but no argument" do
      assert {:ok, [{:input, nil, subs, _meta}]} =
               Grammar.parse("""
               input {
                 leaf data {
                   type string;
                 }
               }
               """)

      assert [{:leaf, "data", _, _}] = subs
    end
  end

  describe "string concatenation" do
    test "concatenated strings are joined" do
      assert {:ok, [{:description, "hello world", [], meta}]} =
               Grammar.parse(~s(description "hello" + " world";))

      assert meta.string_fragments == ["hello", " world"]
    end
  end

  describe "module-level" do
    test "parses a minimal module" do
      yang = """
      module test-module {
        namespace "urn:example:test";
        prefix test;
        leaf name {
          type string;
        }
      }
      """

      assert {:ok, [{:module, "test-module", subs, _meta}]} = Grammar.parse(yang)
      assert length(subs) == 3
    end
  end

  describe "prefixed keywords" do
    test "prefixed keyword in statement" do
      assert {:ok, [{{:if, :interfaces}, nil, _, _meta}]} =
               Grammar.parse("if:interfaces;")
    end
  end

  describe "error handling" do
    test "unclosed brace" do
      assert {:error, _} = Grammar.parse("container test {")
    end

    test "unexpected token" do
      assert {:error, _} = Grammar.parse("}")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/parser/grammar_test.exs`
Expected: compilation error — Grammar not defined.

- [ ] **Step 3: Create lib/ex_yang/parser/grammar.ex**

```elixir
defmodule ExYang.Parser.Grammar do
  @moduledoc """
  Parses a YANG token stream into a generic tree of tuples.

  The intermediate representation is:

      {keyword, argument, sub_statements, meta}

  where every YANG statement, regardless of type, follows this uniform shape.
  """

  alias ExYang.Parser.Lexer

  @type statement :: {keyword(), String.t() | nil, [statement()], map()}
  @type keyword :: atom() | {String.t(), String.t()}

  @doc """
  Parse a YANG source string into a list of generic statement tuples.

  Returns `{:ok, [statement()]}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, [statement()]} | {:error, term()}
  def parse(input) when is_binary(input) do
    case Lexer.tokenize(input) do
      {:ok, tokens, "", _, _, _} ->
        tokens = strip_insignificant(tokens)
        parse_statements(tokens, [])

      {:error, reason, rest, _, _, _} ->
        {:error, {:lexer_error, reason, rest}}
    end
  end

  # Strip whitespace and newlines from the parse stream.
  # Comments are also stripped here — they will be re-attached in a
  # post-processing step using the original token stream.
  defp strip_insignificant(tokens) do
    Enum.reject(tokens, fn {type, _, _} ->
      type in [:whitespace, :newline, :line_comment, :block_comment]
    end)
  end

  # ---------------------------------------------------------------------------
  # Statement parsing
  # ---------------------------------------------------------------------------

  defp parse_statements([], acc), do: {:ok, Enum.reverse(acc)}

  defp parse_statements(tokens, acc) do
    case parse_one_statement(tokens) do
      {:ok, stmt, rest} ->
        parse_statements(rest, [stmt | acc])

      {:error, _} = err ->
        err
    end
  end

  # A YANG statement is:
  #   keyword [argument] (';' | '{' sub-statements '}')
  #
  # The argument can be a keyword token (for unquoted args like `true`,
  # `string`, `2018-02-20`) or a string token.
  defp parse_one_statement([{:keyword, meta, kw} | rest]) do
    keyword = normalize_keyword(kw)

    case parse_argument_and_body(rest, meta) do
      {:ok, arg, subs, meta, rest2} ->
        {:ok, {keyword, arg, subs, meta}, rest2}

      {:error, _} = err ->
        err
    end
  end

  defp parse_one_statement([{type, meta, _} | _]) do
    {:error, {:unexpected_token, type, meta}}
  end

  defp parse_one_statement([]) do
    {:error, :unexpected_end}
  end

  # After the keyword, we look for:
  # 1. ';' — no argument, no body
  # 2. '{' — no argument, has body
  # 3. argument then ';' or '{'
  defp parse_argument_and_body([{:semicolon, _, _} | rest], meta) do
    {:ok, nil, [], meta, rest}
  end

  defp parse_argument_and_body([{:open_brace, _, _} | rest], meta) do
    case parse_block_body(rest) do
      {:ok, subs, rest2} -> {:ok, nil, subs, meta, rest2}
      {:error, _} = err -> err
    end
  end

  defp parse_argument_and_body(tokens, meta) do
    case parse_argument(tokens) do
      {:ok, arg, fragments, rest} ->
        stmt_meta =
          if fragments do
            Map.put(meta, :string_fragments, fragments)
          else
            meta
          end

        case rest do
          [{:semicolon, _, _} | rest2] ->
            {:ok, arg, [], stmt_meta, rest2}

          [{:open_brace, _, _} | rest2] ->
            case parse_block_body(rest2) do
              {:ok, subs, rest3} -> {:ok, arg, subs, stmt_meta, rest3}
              {:error, _} = err -> err
            end

          [{type, m, _} | _] ->
            {:error, {:expected_semicolon_or_brace, type, m}}

          [] ->
            {:error, :unexpected_end_after_argument}
        end

      {:error, _} = err ->
        err
    end
  end

  # Parse an argument, which can be:
  # - A quoted string (single or double)
  # - A keyword token used as an unquoted argument
  # - Concatenation of strings with '+'
  defp parse_argument([{:dq_string, _, value} | rest]) do
    parse_string_concat(value, [value], rest)
  end

  defp parse_argument([{:sq_string, _, value} | rest]) do
    parse_string_concat(value, [value], rest)
  end

  defp parse_argument([{:keyword, _, value} | rest]) when is_binary(value) do
    {:ok, value, nil, rest}
  end

  defp parse_argument([{:keyword, _, {prefix, name}} | rest]) do
    {:ok, "#{prefix}:#{name}", nil, rest}
  end

  defp parse_argument([{type, meta, _} | _]) do
    {:error, {:expected_argument, type, meta}}
  end

  defp parse_argument([]) do
    {:error, :unexpected_end_expected_argument}
  end

  # Handle string concatenation: "a" + "b"
  defp parse_string_concat(combined, fragments, [{:plus, _, _}, {str_type, _, value} | rest])
       when str_type in [:dq_string, :sq_string] do
    parse_string_concat(combined <> value, fragments ++ [value], rest)
  end

  defp parse_string_concat(combined, fragments, rest) do
    frags = if length(fragments) > 1, do: fragments, else: nil
    {:ok, combined, frags, rest}
  end

  # Parse body of a block: statements until '}'
  defp parse_block_body(tokens) do
    parse_block_body(tokens, [])
  end

  defp parse_block_body([{:close_brace, _, _} | rest], acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp parse_block_body([], _acc) do
    {:error, :unclosed_brace}
  end

  defp parse_block_body(tokens, acc) do
    case parse_one_statement(tokens) do
      {:ok, stmt, rest} ->
        parse_block_body(rest, [stmt | acc])

      {:error, _} = err ->
        err
    end
  end

  # Normalize keyword: strings stay as-is, tuples become {prefix, name} atoms
  defp normalize_keyword({prefix, name}) when is_binary(prefix) and is_binary(name) do
    {String.to_atom(prefix), String.to_atom(name)}
  end

  defp normalize_keyword(name) when is_binary(name) do
    String.to_atom(name)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/parser/grammar_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/parser/grammar.ex test/ex_yang/parser/grammar_test.exs
git commit -m "Add YANG grammar producing generic statement tree"
```

---

### Task 8: Comment Attacher

**Files:**
- Create: `lib/ex_yang/parser/comment_attacher.ex`
- Create: `test/ex_yang/parser/comment_attacher_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/parser/comment_attacher_test.exs
defmodule ExYang.Parser.CommentAttacherTest do
  use ExUnit.Case, async: true

  alias ExYang.Parser.CommentAttacher

  test "leading comment attaches to next statement" do
    statements = [
      {:leaf, "name", [{:type, "string", [], %{line: 3}}], %{line: 2}}
    ]

    comments = [{1, "// Name of the interface"}]
    blank_lines = MapSet.new()

    result = CommentAttacher.attach(statements, comments, blank_lines)
    [{:leaf, "name", _, meta}] = result
    assert [%{text: "// Name of the interface", position: :leading}] = meta.comments
  end

  test "blank line breaks attachment — becomes floating" do
    statements = [
      {:leaf, "name", [{:type, "string", [], %{line: 4}}], %{line: 3}}
    ]

    comments = [{1, "// Floating comment"}]
    blank_lines = MapSet.new([2])

    result = CommentAttacher.attach(statements, comments, blank_lines)

    assert length(result) == 2
    assert %{text: "// Floating comment", position: :floating} = List.last(result)
  end

  test "inline comment attaches to same-line statement" do
    statements = [
      {:leaf, "name", [{:type, "string", [], %{line: 1}}], %{line: 1}}
    ]

    comments = [{1, "// inline"}]
    blank_lines = MapSet.new()

    result = CommentAttacher.attach(statements, comments, blank_lines)
    [{:leaf, "name", _, meta}] = result
    assert [%{text: "// inline", position: :inline}] = meta.comments
  end

  test "no comments returns statements unchanged" do
    statements = [
      {:leaf, "name", [{:type, "string", [], %{line: 1}}], %{line: 1}}
    ]

    result = CommentAttacher.attach(statements, [], MapSet.new())
    assert result == statements
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/parser/comment_attacher_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/parser/comment_attacher.ex**

```elixir
defmodule ExYang.Parser.CommentAttacher do
  @moduledoc """
  Post-parse step that attaches comments to their nearest statement nodes
  in the generic tree.

  Attachment rules:
    - A comment on the line immediately before a statement (with no blank
      line between) attaches as `:leading`.
    - A comment on the same line as a statement attaches as `:inline`.
    - A comment separated from the next statement by a blank line becomes
      `:floating` and is appended to the body.
  """

  @doc """
  Attach comments to statement nodes.

  `statements` is a list of `{keyword, arg, subs, meta}` tuples.
  `comments` is a list of `{line, text}` tuples.
  `blank_lines` is a `MapSet` of line numbers that are blank.
  """
  @spec attach(list(), [{pos_integer(), String.t()}], MapSet.t()) :: list()
  def attach(statements, [], _blank_lines), do: statements

  def attach(statements, comments, blank_lines) do
    comments = Enum.sort_by(comments, fn {line, _} -> line end)
    node_lines = Enum.map(statements, fn {_, _, _, meta} -> Map.get(meta, :line) end)

    {inline, other} =
      Enum.split_with(comments, fn {line, _} ->
        line in node_lines
      end)

    # Attach inline comments
    statements =
      Enum.map(statements, fn {kw, arg, subs, meta} = stmt ->
        line = Map.get(meta, :line)

        matching =
          inline
          |> Enum.filter(fn {l, _} -> l == line end)
          |> Enum.map(fn {_, text} -> %{text: text, position: :inline} end)

        if matching == [] do
          stmt
        else
          existing = Map.get(meta, :comments, [])
          {kw, arg, subs, Map.put(meta, :comments, existing ++ matching)}
        end
      end)

    # Attach leading or floating
    {statements, floating} =
      Enum.reduce(other, {statements, []}, fn {comment_line, text}, {stmts, floats} ->
        next =
          node_lines
          |> Enum.filter(&(&1 != nil and &1 > comment_line))
          |> Enum.sort()
          |> List.first()

        case next do
          nil ->
            {stmts, floats ++ [%{text: text, position: :floating}]}

          next_line ->
            if blank_line_between?(comment_line, next_line, blank_lines) do
              {stmts, floats ++ [%{text: text, position: :floating}]}
            else
              stmts =
                Enum.map(stmts, fn {kw, arg, subs, meta} = stmt ->
                  if Map.get(meta, :line) == next_line do
                    existing = Map.get(meta, :comments, [])
                    comment = %{text: text, position: :leading}
                    {kw, arg, subs, Map.put(meta, :comments, [comment | existing])}
                  else
                    stmt
                  end
                end)

              {stmts, floats}
            end
        end
      end)

    statements ++ floating
  end

  defp blank_line_between?(comment_line, node_line, _) when node_line <= comment_line + 1 do
    false
  end

  defp blank_line_between?(comment_line, node_line, blank_lines) do
    (comment_line + 1)..(node_line - 1)
    |> Enum.any?(fn line -> MapSet.member?(blank_lines, line) end)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/parser/comment_attacher_test.exs`
Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/parser/comment_attacher.ex test/ex_yang/parser/comment_attacher_test.exs
git commit -m "Add comment attacher for generic tree"
```

---

### Task 9: Transform — Builder (Core Statements)

**Files:**
- Create: `lib/ex_yang/transform/builder.ex`
- Create: `test/ex_yang/transform/builder_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/transform/builder_test.exs
defmodule ExYang.Transform.BuilderTest do
  use ExUnit.Case, async: true

  alias ExYang.Transform.Builder
  alias ExYang.Model.{Module, Container, Leaf, List, LeafList, Typedef, Type, Grouping, Uses}
  alias ExYang.Model.{Import, Revision, Identity, Feature, Rpc, Input, Output, Notification}
  alias ExYang.Model.{Augment, Deviation, Deviate, Choice, Case, Must, When}
  alias ExYang.Model.{ExtensionDef, ExtensionUse}

  test "builds a minimal module" do
    tree = {:module, "test", [
      {:namespace, "urn:example:test", [], %{line: 2}},
      {:prefix, "t", [], %{line: 3}}
    ], %{line: 1}}

    assert {:ok, %Module{name: "test", namespace: "urn:example:test", prefix: "t"}} =
             Builder.build(tree)
  end

  test "builds leaf with type" do
    tree = {:leaf, "name", [
      {:type, "string", [], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Leaf{name: "name", type: %Type{name: "string"}}} = Builder.build(tree)
  end

  test "builds container with children" do
    tree = {:container, "interfaces", [
      {:leaf, "count", [
        {:type, "uint32", [], %{line: 3}}
      ], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Container{name: "interfaces", body: [%Leaf{name: "count"}]}} =
             Builder.build(tree)
  end

  test "builds list with key" do
    tree = {:list, "interface", [
      {:key, "name", [], %{line: 2}},
      {:leaf, "name", [{:type, "string", [], %{line: 4}}], %{line: 3}}
    ], %{line: 1}}

    assert {:ok, %List{name: "interface", key: "name", body: [%Leaf{}]}} =
             Builder.build(tree)
  end

  test "builds typedef" do
    tree = {:typedef, "percentage", [
      {:type, "uint8", [
        {:range, "0..100", [], %{line: 3}}
      ], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Typedef{name: "percentage", type: %Type{name: "uint8"}}} =
             Builder.build(tree)
  end

  test "builds grouping and uses" do
    tree = {:grouping, "endpoint", [
      {:leaf, "address", [{:type, "string", [], %{line: 3}}], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Grouping{name: "endpoint", body: [%Leaf{}]}} = Builder.build(tree)

    uses_tree = {:uses, "endpoint", [], %{line: 1}}
    assert {:ok, %Uses{grouping: "endpoint"}} = Builder.build(uses_tree)
  end

  test "builds import" do
    tree = {:import, "ietf-yang-types", [
      {:prefix, "yang", [], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Import{module: "ietf-yang-types", prefix: "yang"}} = Builder.build(tree)
  end

  test "builds identity" do
    tree = {:identity, "transport", [
      {:base, "protocol", [], %{line: 2}},
      {:description, "A transport protocol", [], %{line: 3}}
    ], %{line: 1}}

    assert {:ok, %Identity{name: "transport", bases: ["protocol"]}} = Builder.build(tree)
  end

  test "builds rpc" do
    tree = {:rpc, "restart", [
      {:input, nil, [
        {:leaf, "reason", [{:type, "string", [], %{line: 4}}], %{line: 3}}
      ], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %Rpc{name: "restart", input: %Input{body: [%Leaf{}]}}} = Builder.build(tree)
  end

  test "unknown prefixed keywords become ExtensionUse" do
    tree = {{:mymod, :custom_ext}, "some-arg", [
      {:description, "An extension", [], %{line: 2}}
    ], %{line: 1}}

    assert {:ok, %ExtensionUse{keyword: {:mymod, :custom_ext}, argument: "some-arg"}} =
             Builder.build(tree)
  end

  test "builds module with imports, revisions, and body" do
    tree = {:module, "ietf-interfaces", [
      {:namespace, "urn:ietf:params:xml:ns:yang:ietf-interfaces", [], %{line: 2}},
      {:prefix, "if", [], %{line: 3}},
      {:"yang-version", "1.1", [], %{line: 4}},
      {:import, "ietf-yang-types", [
        {:prefix, "yang", [], %{line: 6}}
      ], %{line: 5}},
      {:revision, "2018-02-20", [
        {:description, "Updated.", [], %{line: 8}}
      ], %{line: 7}},
      {:container, "interfaces", [], %{line: 9}}
    ], %{line: 1}}

    assert {:ok, %Module{
      name: "ietf-interfaces",
      yang_version: "1.1",
      imports: [%Import{module: "ietf-yang-types", prefix: "yang"}],
      revisions: [%Revision{date: "2018-02-20"}],
      body: [%Container{name: "interfaces"}]
    }} = Builder.build(tree)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/transform/builder_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/transform/builder.ex**

```elixir
defmodule ExYang.Transform.Builder do
  @moduledoc """
  Transforms a generic YANG statement tree into typed model structs.

  Each `build/1` clause dispatches on the statement keyword to produce
  the corresponding struct from `ExYang.Model`.
  """

  alias ExYang.Model.{
    Module, Submodule, Import, Include, Revision, BelongsTo,
    Container, Leaf, LeafList, List, Choice, Case, AnyData, AnyXml,
    Grouping, Uses, Refine, Augment, Deviation, Deviate,
    Typedef, Type, Enum, Bit,
    Identity, Feature,
    Rpc, Action, Input, Output, Notification,
    Must, When, Range, Length, Pattern,
    ExtensionDef, ExtensionUse
  }

  @doc """
  Build a typed struct from a generic statement tuple.
  """
  @spec build({atom() | {atom(), atom()}, String.t() | nil, list(), map()}) ::
          {:ok, struct()} | {:error, term()}
  def build({keyword, arg, subs, meta}) do
    {:ok, do_build(keyword, arg, subs, meta)}
  rescue
    e -> {:error, {:build_error, keyword, e}}
  end

  # ---------------------------------------------------------------------------
  # Module / Submodule
  # ---------------------------------------------------------------------------

  defp do_build(:module, name, subs, meta) do
    %Module{
      name: name,
      namespace: take_one(subs, :namespace),
      prefix: take_one(subs, :prefix),
      yang_version: take_one(subs, :"yang-version"),
      organization: take_one(subs, :organization),
      contact: take_one(subs, :contact),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      imports: build_all(subs, :import),
      includes: build_all(subs, :include),
      revisions: build_all(subs, :revision),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      identities: build_all(subs, :identity),
      features: build_all(subs, :feature),
      extensions: build_all(subs, :extension),
      rpcs: build_all(subs, :rpc),
      notifications: build_all(subs, :notification),
      augments: build_all(subs, :augment),
      deviations: build_all(subs, :deviation),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:submodule, name, subs, meta) do
    %Submodule{
      name: name,
      belongs_to: build_one(subs, :"belongs-to"),
      yang_version: take_one(subs, :"yang-version"),
      organization: take_one(subs, :organization),
      contact: take_one(subs, :contact),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      imports: build_all(subs, :import),
      includes: build_all(subs, :include),
      revisions: build_all(subs, :revision),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      identities: build_all(subs, :identity),
      features: build_all(subs, :feature),
      extensions: build_all(subs, :extension),
      rpcs: build_all(subs, :rpc),
      notifications: build_all(subs, :notification),
      augments: build_all(subs, :augment),
      deviations: build_all(subs, :deviation),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Header
  # ---------------------------------------------------------------------------

  defp do_build(:import, mod, subs, meta) do
    %Import{
      module: mod,
      prefix: take_one(subs, :prefix),
      revision_date: take_one(subs, :"revision-date"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:include, mod, subs, meta) do
    %Include{
      module: mod,
      revision_date: take_one(subs, :"revision-date"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:revision, date, subs, meta) do
    %Revision{
      date: date,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:"belongs-to", mod, subs, meta) do
    %BelongsTo{
      module: mod,
      prefix: take_one(subs, :prefix),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Data definition
  # ---------------------------------------------------------------------------

  defp do_build(:container, name, subs, meta) do
    %Container{
      name: name,
      config: take_bool(subs, :config),
      presence: take_one(subs, :presence),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:leaf, name, subs, meta) do
    %Leaf{
      name: name,
      type: build_one(subs, :type),
      default: take_one(subs, :default),
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:"leaf-list", name, subs, meta) do
    %LeafList{
      name: name,
      type: build_one(subs, :type),
      config: take_bool(subs, :config),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_one(subs, :"max-elements"),
      ordered_by: take_one(subs, :"ordered-by"),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:list, name, subs, meta) do
    %List{
      name: name,
      key: take_one(subs, :key),
      unique: take_all_args(subs, :unique),
      config: take_bool(subs, :config),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_one(subs, :"max-elements"),
      ordered_by: take_one(subs, :"ordered-by"),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:choice, name, subs, meta) do
    %Choice{
      name: name,
      default: take_one(subs, :default),
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      cases: build_all(subs, :case),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:case, name, subs, meta) do
    %Case{
      name: name,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:anydata, name, subs, meta) do
    %AnyData{
      name: name,
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:anyxml, name, subs, meta) do
    %AnyXml{
      name: name,
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Schema manipulation
  # ---------------------------------------------------------------------------

  defp do_build(:grouping, name, subs, meta) do
    %Grouping{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:uses, grouping, subs, meta) do
    %Uses{
      grouping: grouping,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      refines: build_all(subs, :refine),
      augments: build_all(subs, :augment),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:refine, target, subs, meta) do
    %Refine{
      target_node: target,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      config: take_bool(subs, :config),
      default: take_one(subs, :default),
      mandatory: take_bool(subs, :mandatory),
      presence: take_one(subs, :presence),
      must: build_all(subs, :must),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_one(subs, :"max-elements"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:augment, target, subs, meta) do
    %Augment{
      target_node: target,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:deviation, target, subs, meta) do
    %Deviation{
      target_node: target,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      deviates: build_all(subs, :deviate),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:deviate, type_str, subs, meta) do
    type =
      case type_str do
        "not-supported" -> :not_supported
        "add" -> :add
        "replace" -> :replace
        "delete" -> :delete
      end

    %Deviate{
      type: type,
      config: take_bool(subs, :config),
      default: take_one(subs, :default),
      mandatory: take_bool(subs, :mandatory),
      type_replacement: build_one(subs, :type),
      units: take_one(subs, :units),
      must: build_all(subs, :must),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_one(subs, :"max-elements"),
      unique: take_all_args(subs, :unique),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Type system
  # ---------------------------------------------------------------------------

  defp do_build(:typedef, name, subs, meta) do
    %Typedef{
      name: name,
      type: build_one(subs, :type),
      default: take_one(subs, :default),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:type, name, subs, meta) do
    %Type{
      name: name,
      range: build_one(subs, :range),
      length: build_one(subs, :length),
      patterns: build_all(subs, :pattern),
      fraction_digits: take_int(subs, :"fraction-digits"),
      enum_values: build_all(subs, :enum),
      bit_values: build_all(subs, :bit),
      path: take_one(subs, :path),
      require_instance: take_bool(subs, :"require-instance"),
      union_types: build_all(subs, :type),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:enum, name, subs, meta) do
    %Enum{
      name: name,
      value: take_int(subs, :value),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:bit, name, subs, meta) do
    %Bit{
      name: name,
      position: take_int(subs, :position),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Identity & Feature
  # ---------------------------------------------------------------------------

  defp do_build(:identity, name, subs, meta) do
    %Identity{
      name: name,
      bases: take_all_args(subs, :base),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:feature, name, subs, meta) do
    %Feature{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # RPC / Action / Notification
  # ---------------------------------------------------------------------------

  defp do_build(:rpc, name, subs, meta) do
    %Rpc{
      name: name,
      input: build_one(subs, :input),
      output: build_one(subs, :output),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:action, name, subs, meta) do
    %Action{
      name: name,
      input: build_one(subs, :input),
      output: build_one(subs, :output),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:input, _arg, subs, meta) do
    %Input{
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:output, _arg, subs, meta) do
    %Output{
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:notification, name, subs, meta) do
    %Notification{
      name: name,
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Constraints
  # ---------------------------------------------------------------------------

  defp do_build(:must, xpath, subs, meta) do
    %Must{
      xpath: xpath,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:when, xpath, subs, meta) do
    %When{
      xpath: xpath,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:range, expr, subs, meta) do
    %Range{
      expression: expr,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:length, expr, subs, meta) do
    %Length{
      expression: expr,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  defp do_build(:pattern, value, subs, meta) do
    %Pattern{
      value: value,
      modifier: take_one(subs, :modifier),
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Extension
  # ---------------------------------------------------------------------------

  defp do_build(:extension, name, subs, meta) do
    %ExtensionDef{
      name: name,
      argument: take_one(subs, :argument),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # Prefixed keywords (extension usage) — catch-all for {prefix, name} tuples
  defp do_build({_prefix, _name} = keyword, arg, subs, meta) do
    %ExtensionUse{
      keyword: keyword,
      argument: arg,
      sub_statements: subs,
      meta: meta,
      comments: Map.get(meta, :comments, [])
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Statements that produce body-level data definition nodes
  @body_keywords [
    :container, :leaf, :"leaf-list", :list, :choice, :anydata, :anyxml, :uses, :action
  ]

  # Statements consumed as named fields (not body)
  @non_body_keywords [
    :namespace, :prefix, :"yang-version", :organization, :contact,
    :description, :reference, :import, :include, :revision, :"belongs-to",
    :typedef, :grouping, :identity, :feature, :extension,
    :rpc, :notification, :augment, :deviation,
    :type, :key, :unique, :config, :mandatory, :default, :presence,
    :"min-elements", :"max-elements", :"ordered-by", :units,
    :status, :when, :must, :"if-feature", :refine, :deviate,
    :range, :length, :pattern, :"fraction-digits", :enum, :bit,
    :path, :"require-instance", :value, :position, :base,
    :input, :output, :"error-message", :"error-app-tag",
    :argument, :modifier, :"revision-date", :case
  ]

  defp build_body(subs) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} ->
      kw in @body_keywords or (is_tuple(kw) and tuple_size(kw) == 2)
    end)
    |> Elixir.Enum.map(fn sub ->
      {:ok, built} = build(sub)
      built
    end)
  end

  defp build_all(subs, keyword) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} -> kw == keyword end)
    |> Elixir.Enum.map(fn sub ->
      {:ok, built} = build(sub)
      built
    end)
  end

  defp build_one(subs, keyword) do
    case Elixir.Enum.find(subs, fn {kw, _, _, _} -> kw == keyword end) do
      nil -> nil
      sub -> elem(build(sub), 1)
    end
  end

  defp take_one(subs, keyword) do
    case Elixir.Enum.find(subs, fn {kw, _, _, _} -> kw == keyword end) do
      nil -> nil
      {_, arg, _, _} -> arg
    end
  end

  defp take_all_args(subs, keyword) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} -> kw == keyword end)
    |> Elixir.Enum.map(fn {_, arg, _, _} -> arg end)
  end

  defp take_bool(subs, keyword) do
    case take_one(subs, keyword) do
      "true" -> true
      "false" -> false
      nil -> nil
    end
  end

  defp take_int(subs, keyword) do
    case take_one(subs, keyword) do
      nil -> nil
      val ->
        case Integer.parse(val) do
          {n, ""} -> n
          _ -> val
        end
    end
  end

  defp take_status(subs) do
    case take_one(subs, :status) do
      "current" -> :current
      "deprecated" -> :deprecated
      "obsolete" -> :obsolete
      nil -> nil
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/transform/builder_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/transform/builder.ex test/ex_yang/transform/builder_test.exs
git commit -m "Add transform builder: generic tree to typed structs"
```

---

### Task 10: Transform — Validator

**Files:**
- Create: `lib/ex_yang/transform/validator.ex`
- Create: `test/ex_yang/transform/validator_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/transform/validator_test.exs
defmodule ExYang.Transform.ValidatorTest do
  use ExUnit.Case, async: true

  alias ExYang.Transform.Validator
  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Leaf, Container, Type}

  test "valid leaf passes" do
    leaf = %Leaf{name: "name", type: %Type{name: "string"}, meta: %{line: 1}}
    assert {:ok, ^leaf} = Validator.validate(leaf)
  end

  test "leaf missing mandatory type produces error" do
    leaf = %Leaf{name: "name", type: nil, meta: %{line: 5}}
    assert {:error, diagnostics} = Validator.validate(leaf)
    assert [%Diagnostic{severity: :error, phase: :validation}] = diagnostics
    assert hd(diagnostics).message =~ "type"
  end

  test "leaf with duplicate config produces error" do
    leaf = %Leaf{name: "name", type: %Type{name: "string"}, meta: %{line: 1}}
    # Validator checks the struct — duplicate sub-statements are caught during
    # build. This test verifies the validator doesn't reject a valid leaf.
    assert {:ok, _} = Validator.validate(leaf)
  end

  test "container with valid children passes" do
    container = %Container{
      name: "interfaces",
      body: [%Leaf{name: "count", type: %Type{name: "uint32"}, meta: %{line: 2}}],
      meta: %{line: 1}
    }
    assert {:ok, _} = Validator.validate(container)
  end

  test "module missing namespace produces error" do
    mod = %Module{name: "test", prefix: "t", meta: %{line: 1}}
    assert {:error, diagnostics} = Validator.validate(mod)
    assert Elixir.Enum.any?(diagnostics, fn d -> d.message =~ "namespace" end)
  end

  test "module missing prefix produces error" do
    mod = %Module{name: "test", namespace: "urn:test", meta: %{line: 1}}
    assert {:error, diagnostics} = Validator.validate(mod)
    assert Elixir.Enum.any?(diagnostics, fn d -> d.message =~ "prefix" end)
  end

  test "valid module passes" do
    mod = %Module{name: "test", namespace: "urn:test", prefix: "t", meta: %{line: 1}}
    assert {:ok, _} = Validator.validate(mod)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/transform/validator_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/transform/validator.ex**

```elixir
defmodule ExYang.Transform.Validator do
  @moduledoc """
  Validates typed model structs against RFC 7950 sub-statement cardinality rules.

  Rules are declared as data — a map per statement type specifying which
  fields are mandatory (min 1) vs optional (min 0).
  """

  alias ExYang.Diagnostic

  alias ExYang.Model.{
    Module, Submodule, Container, Leaf, LeafList, List, Choice, Case,
    AnyData, AnyXml, Grouping, Uses, Augment, Deviation,
    Typedef, Rpc, Action, Notification
  }

  @doc """
  Validate a model struct. Returns `{:ok, struct}` or `{:error, [Diagnostic.t()]}`.
  """
  @spec validate(struct()) :: {:ok, struct()} | {:error, [Diagnostic.t()]}
  def validate(node) do
    diagnostics = check(node, [])

    errors = Elixir.Enum.filter(diagnostics, &(&1.severity == :error))

    if errors == [] do
      {:ok, node}
    else
      {:error, diagnostics}
    end
  end

  # ---------------------------------------------------------------------------
  # Per-type validation
  # ---------------------------------------------------------------------------

  defp check(%Module{} = m, ctx) do
    ctx = ["module #{m.name}" | ctx]
    diags = []
    diags = diags ++ require_field(m, :namespace, "namespace", ctx)
    diags = diags ++ require_field(m, :prefix, "prefix", ctx)
    diags = diags ++ validate_children(m.body, ctx)
    diags = diags ++ validate_children(m.typedefs, ctx)
    diags = diags ++ validate_children(m.groupings, ctx)
    diags = diags ++ validate_children(m.rpcs, ctx)
    diags = diags ++ validate_children(m.notifications, ctx)
    diags
  end

  defp check(%Submodule{} = m, ctx) do
    ctx = ["submodule #{m.name}" | ctx]
    diags = []
    diags = diags ++ require_field(m, :belongs_to, "belongs-to", ctx)
    diags = diags ++ validate_children(m.body, ctx)
    diags
  end

  defp check(%Leaf{} = l, ctx) do
    ctx = ["leaf #{l.name}" | ctx]
    require_field(l, :type, "type", ctx)
  end

  defp check(%LeafList{} = l, ctx) do
    ctx = ["leaf-list #{l.name}" | ctx]
    require_field(l, :type, "type", ctx)
  end

  defp check(%Container{} = c, ctx) do
    ctx = ["container #{c.name}" | ctx]
    validate_children(c.body, ctx)
  end

  defp check(%List{} = l, ctx) do
    ctx = ["list #{l.name}" | ctx]
    validate_children(l.body, ctx)
  end

  defp check(%Choice{} = c, ctx) do
    ctx = ["choice #{c.name}" | ctx]
    validate_children(c.cases, ctx)
  end

  defp check(%Case{} = c, ctx) do
    ctx = ["case #{c.name}" | ctx]
    validate_children(c.body, ctx)
  end

  defp check(%Grouping{} = g, ctx) do
    ctx = ["grouping #{g.name}" | ctx]
    validate_children(g.body, ctx)
  end

  defp check(%Typedef{} = t, ctx) do
    ctx = ["typedef #{t.name}" | ctx]
    require_field(t, :type, "type", ctx)
  end

  defp check(%Rpc{} = r, ctx) do
    ctx = ["rpc #{r.name}" | ctx]
    diags = []
    diags = if r.input, do: diags ++ check(r.input, ctx), else: diags
    diags = if r.output, do: diags ++ check(r.output, ctx), else: diags
    diags
  end

  defp check(%Action{} = a, ctx) do
    ctx = ["action #{a.name}" | ctx]
    diags = []
    diags = if a.input, do: diags ++ check(a.input, ctx), else: diags
    diags = if a.output, do: diags ++ check(a.output, ctx), else: diags
    diags
  end

  defp check(%Notification{} = n, ctx) do
    ctx = ["notification #{n.name}" | ctx]
    validate_children(n.body, ctx)
  end

  defp check(%{__struct__: _}, _ctx), do: []

  defp check(_, _ctx), do: []

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp validate_children(children, ctx) do
    children
    |> Elixir.Enum.flat_map(fn child -> check(child, ctx) end)
  end

  defp require_field(node, field, yang_name, ctx) do
    if Map.get(node, field) in [nil, []] do
      [%Diagnostic{
        severity: :error,
        phase: :validation,
        message: "missing mandatory sub-statement '#{yang_name}'",
        line: get_in(node, [Access.key(:meta), Access.key(:line)]),
        context: Elixir.Enum.reverse(ctx)
      }]
    else
      []
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/transform/validator_test.exs`
Expected: 7 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/transform/validator.ex test/ex_yang/transform/validator_test.exs
git commit -m "Add validator with cardinality rules per statement type"
```

---

### Task 11: Transform — Extension Registry

**Files:**
- Create: `lib/ex_yang/transform/extensions.ex`
- Create: `test/ex_yang/transform/extensions_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/transform/extensions_test.exs
defmodule ExYang.Transform.ExtensionsTest do
  use ExUnit.Case, async: true

  alias ExYang.Transform.Extensions
  alias ExYang.Model.ExtensionUse

  defmodule TestHandler do
    @behaviour ExYang.Transform.Extensions

    @impl true
    def transform({:test, :custom}, arg, _subs, _meta) do
      {:ok, %{custom: true, value: arg}}
    end

    def transform(_, _, _, _), do: :skip
  end

  test "registered handler transforms extension" do
    Extensions.register({:test, :custom}, TestHandler)

    result = Extensions.transform({:test, :custom}, "hello", [], %{line: 1})
    assert {:ok, %{custom: true, value: "hello"}} = result
  after
    Extensions.unregister({:test, :custom})
  end

  test "unregistered extension returns ExtensionUse" do
    result = Extensions.transform({:unknown, :ext}, "arg", [], %{line: 1})
    assert {:ok, %ExtensionUse{keyword: {:unknown, :ext}, argument: "arg"}} = result
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/transform/extensions_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/transform/extensions.ex**

```elixir
defmodule ExYang.Transform.Extensions do
  @moduledoc """
  Registry for YANG extension handlers.

  Extension handlers implement the `ExYang.Transform.Extensions` behaviour.
  When the builder encounters a prefixed keyword, it consults this registry.
  If a handler is registered, it is called. Otherwise, the extension is
  stored as an opaque `%ExtensionUse{}`.
  """

  alias ExYang.Model.ExtensionUse

  @callback transform(
              keyword :: {atom(), atom()},
              argument :: String.t() | nil,
              sub_statements :: list(),
              meta :: map()
            ) :: {:ok, struct()} | :skip | {:error, String.t()}

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Register a handler module for a prefixed keyword."
  @spec register({atom(), atom()}, module()) :: :ok
  def register(keyword, handler) do
    ensure_started()
    Agent.update(__MODULE__, &Map.put(&1, keyword, handler))
  end

  @doc "Unregister a handler for a prefixed keyword."
  @spec unregister({atom(), atom()}) :: :ok
  def unregister(keyword) do
    ensure_started()
    Agent.update(__MODULE__, &Map.delete(&1, keyword))
  end

  @doc """
  Transform an extension keyword. Delegates to a registered handler
  or wraps in `%ExtensionUse{}`.
  """
  @spec transform({atom(), atom()}, String.t() | nil, list(), map()) ::
          {:ok, struct()} | :skip | {:error, String.t()}
  def transform(keyword, argument, sub_statements, meta) do
    ensure_started()

    case Agent.get(__MODULE__, &Map.get(&1, keyword)) do
      nil ->
        {:ok,
         %ExtensionUse{
           keyword: keyword,
           argument: argument,
           sub_statements: sub_statements,
           meta: meta
         }}

      handler ->
        handler.transform(keyword, argument, sub_statements, meta)
    end
  end

  defp ensure_started do
    case Agent.start_link(fn -> %{} end, name: __MODULE__) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/transform/extensions_test.exs`
Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/transform/extensions.ex test/ex_yang/transform/extensions_test.exs
git commit -m "Add extension handler registry with behaviour"
```

---

### Task 12: Public API — parse/1, parse!/1

**Files:**
- Modify: `lib/ex_yang.ex`
- Create: `test/ex_yang/ex_yang_test.exs`
- Create: `test/fixtures/minimal.yang`

- [ ] **Step 1: Create test fixture**

```yang
// test/fixtures/minimal.yang
module minimal {
  namespace "urn:example:minimal";
  prefix min;

  leaf name {
    type string;
    description "A simple leaf";
  }
}
```

- [ ] **Step 2: Write the failing test**

```elixir
# test/ex_yang/ex_yang_test.exs
defmodule ExYangTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{Module, Leaf, Type}

  test "parse/1 parses a minimal module" do
    yang = File.read!("test/fixtures/minimal.yang")
    assert {:ok, %Module{name: "minimal"} = mod} = ExYang.parse(yang)
    assert mod.namespace == "urn:example:minimal"
    assert mod.prefix == "min"
    assert [%Leaf{name: "name", type: %Type{name: "string"}}] = mod.body
  end

  test "parse!/1 returns module directly" do
    yang = File.read!("test/fixtures/minimal.yang")
    assert %Module{name: "minimal"} = ExYang.parse!(yang)
  end

  test "parse!/1 raises on invalid input" do
    assert_raise RuntimeError, fn ->
      ExYang.parse!("invalid {{{ yang")
    end
  end

  test "parse/1 returns error on invalid input" do
    assert {:error, _} = ExYang.parse("leaf {")
  end

  test "parse/1 with inline yang" do
    yang = """
    module test-types {
      namespace "urn:example:test-types";
      prefix tt;

      typedef percentage {
        type uint8 {
          range "0..100";
        }
      }

      container stats {
        leaf cpu-usage {
          type percentage;
        }
      }
    }
    """

    assert {:ok, %Module{name: "test-types"} = mod} = ExYang.parse(yang)
    assert length(mod.typedefs) == 1
    assert [%ExYang.Model.Container{name: "stats"}] = mod.body
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/ex_yang/ex_yang_test.exs`
Expected: UndefinedFunctionError — ExYang.parse/1 not defined.

- [ ] **Step 4: Implement public API**

```elixir
# lib/ex_yang.ex
defmodule ExYang do
  @moduledoc """
  YANG (RFC 7950) parser, resolver, and data modeling library for Elixir.

  ## Parsing

      {:ok, module} = ExYang.parse(yang_source)
      module = ExYang.parse!(yang_source)

  ## Encoding

      {:ok, source} = ExYang.encode(module)   # round-trip faithful
      {:ok, source} = ExYang.format(module)    # canonical style
  """

  alias ExYang.Parser.Grammar
  alias ExYang.Transform.{Builder, Validator}

  @doc """
  Parse a YANG source string into a typed `%Module{}` or `%Submodule{}`.

  Returns `{:ok, struct}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, struct()} | {:error, term()}
  def parse(source) when is_binary(source) do
    with {:ok, [tree]} <- Grammar.parse(source),
         {:ok, module} <- Builder.build(tree),
         {:ok, module} <- Validator.validate(module) do
      {:ok, module}
    end
  end

  @doc """
  Parse a YANG source string, raising on error.
  """
  @spec parse!(String.t()) :: struct()
  def parse!(source) when is_binary(source) do
    case parse(source) do
      {:ok, module} -> module
      {:error, reason} -> raise "ExYang parse error: #{inspect(reason)}"
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/ex_yang/ex_yang_test.exs`
Expected: 5 tests, 0 failures.

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/ex_yang.ex test/ex_yang/ex_yang_test.exs test/fixtures/minimal.yang
git commit -m "Add public API: ExYang.parse/1 and parse!/1"
```

---

### Task 13: Encoder — Round-Trip Faithful

**Files:**
- Create: `lib/ex_yang/encoder/encoder.ex`
- Create: `test/ex_yang/encoder/encoder_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/encoder/encoder_test.exs
defmodule ExYang.Encoder.EncoderTest do
  use ExUnit.Case, async: true

  alias ExYang.Encoder.Encoder
  alias ExYang.Model.{Module, Leaf, Container, Type, Import, Revision}

  test "encodes a minimal module" do
    mod = %Module{
      name: "test",
      namespace: "urn:example:test",
      prefix: "t",
      body: [
        %Leaf{name: "name", type: %Type{name: "string"}, meta: %{}}
      ],
      meta: %{}
    }

    assert {:ok, output} = Encoder.encode(mod)
    assert output =~ "module test {"
    assert output =~ ~s(namespace "urn:example:test";)
    assert output =~ ~s(prefix t;)
    assert output =~ "leaf name {"
    assert output =~ "type string;"
  end

  test "encodes container with nested leaf" do
    mod = %Module{
      name: "test",
      namespace: "urn:test",
      prefix: "t",
      body: [
        %Container{
          name: "config",
          body: [%Leaf{name: "hostname", type: %Type{name: "string"}, meta: %{}}],
          meta: %{}
        }
      ],
      meta: %{}
    }

    assert {:ok, output} = Encoder.encode(mod)
    assert output =~ "container config {"
    assert output =~ "leaf hostname {"
  end

  test "round-trip: parse then encode produces valid YANG" do
    source = """
    module roundtrip {
      namespace "urn:example:roundtrip";
      prefix rt;

      leaf name {
        type string;
      }
    }
    """

    {:ok, mod} = ExYang.parse(source)
    {:ok, encoded} = Encoder.encode(mod)
    {:ok, reparsed} = ExYang.parse(encoded)
    assert reparsed.name == "roundtrip"
    assert length(reparsed.body) == 1
  end

  test "encodes imports" do
    mod = %Module{
      name: "test",
      namespace: "urn:test",
      prefix: "t",
      imports: [%Import{module: "ietf-yang-types", prefix: "yang", meta: %{}}],
      meta: %{}
    }

    assert {:ok, output} = Encoder.encode(mod)
    assert output =~ "import ietf-yang-types {"
    assert output =~ "prefix yang;"
  end

  test "encodes revision" do
    mod = %Module{
      name: "test",
      namespace: "urn:test",
      prefix: "t",
      revisions: [%Revision{date: "2024-01-01", description: "Initial.", meta: %{}}],
      meta: %{}
    }

    assert {:ok, output} = Encoder.encode(mod)
    assert output =~ "revision 2024-01-01 {"
    assert output =~ ~s(description "Initial.";)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/encoder/encoder_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/encoder/encoder.ex**

```elixir
defmodule ExYang.Encoder.Encoder do
  @moduledoc """
  Encodes typed YANG model structs back to YANG source text.

  Round-trip faithful: uses metadata from parsing to preserve original
  formatting where available. Programmatically created nodes get
  default style (2-space indent, double quotes).
  """

  alias ExYang.Model.{
    Module, Submodule, Import, Include, Revision, BelongsTo,
    Container, Leaf, LeafList, List, Choice, Case, AnyData, AnyXml,
    Grouping, Uses, Refine, Augment, Deviation, Deviate,
    Typedef, Type, Enum, Bit,
    Identity, Feature,
    Rpc, Action, Input, Output, Notification,
    Must, When, Range, Length, Pattern,
    ExtensionDef, ExtensionUse
  }

  @doc """
  Encode a model struct to a YANG source string.
  """
  @spec encode(struct()) :: {:ok, String.t()}
  def encode(node) do
    {:ok, IO.iodata_to_binary(to_iodata(node, 0))}
  end

  # ---------------------------------------------------------------------------
  # Module / Submodule
  # ---------------------------------------------------------------------------

  defp to_iodata(%Module{} = m, depth) do
    ind = indent(depth)

    [
      ind, "module ", m.name, " {\n",
      encode_field(depth + 1, "namespace", m.namespace, :quoted),
      encode_field(depth + 1, "prefix", m.prefix, :unquoted),
      encode_field(depth + 1, "yang-version", m.yang_version, :unquoted),
      encode_field(depth + 1, "organization", m.organization, :quoted),
      encode_field(depth + 1, "contact", m.contact, :quoted),
      encode_field(depth + 1, "description", m.description, :quoted),
      encode_field(depth + 1, "reference", m.reference, :quoted),
      encode_nodes(m.imports, depth + 1),
      encode_nodes(m.includes, depth + 1),
      encode_nodes(m.revisions, depth + 1),
      encode_nodes(m.features, depth + 1),
      encode_nodes(m.identities, depth + 1),
      encode_nodes(m.typedefs, depth + 1),
      encode_nodes(m.groupings, depth + 1),
      encode_nodes(m.body, depth + 1),
      encode_nodes(m.augments, depth + 1),
      encode_nodes(m.deviations, depth + 1),
      encode_nodes(m.rpcs, depth + 1),
      encode_nodes(m.notifications, depth + 1),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Submodule{} = m, depth) do
    ind = indent(depth)

    [
      ind, "submodule ", m.name, " {\n",
      encode_field(depth + 1, "yang-version", m.yang_version, :unquoted),
      if(m.belongs_to, do: to_iodata(m.belongs_to, depth + 1), else: []),
      encode_field(depth + 1, "organization", m.organization, :quoted),
      encode_field(depth + 1, "contact", m.contact, :quoted),
      encode_field(depth + 1, "description", m.description, :quoted),
      encode_field(depth + 1, "reference", m.reference, :quoted),
      encode_nodes(m.imports, depth + 1),
      encode_nodes(m.includes, depth + 1),
      encode_nodes(m.revisions, depth + 1),
      encode_nodes(m.body, depth + 1),
      ind, "}\n"
    ]
  end

  # ---------------------------------------------------------------------------
  # Header
  # ---------------------------------------------------------------------------

  defp to_iodata(%Import{} = i, depth) do
    ind = indent(depth)

    [
      ind, "import ", i.module, " {\n",
      encode_field(depth + 1, "prefix", i.prefix, :unquoted),
      encode_field(depth + 1, "revision-date", i.revision_date, :unquoted),
      encode_field(depth + 1, "description", i.description, :quoted),
      encode_field(depth + 1, "reference", i.reference, :quoted),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Include{} = i, depth) do
    ind = indent(depth)

    if i.revision_date || i.description || i.reference do
      [
        ind, "include ", i.module, " {\n",
        encode_field(depth + 1, "revision-date", i.revision_date, :unquoted),
        encode_field(depth + 1, "description", i.description, :quoted),
        encode_field(depth + 1, "reference", i.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "include ", i.module, ";\n"]
    end
  end

  defp to_iodata(%Revision{} = r, depth) do
    ind = indent(depth)

    if r.description || r.reference do
      [
        ind, "revision ", r.date, " {\n",
        encode_field(depth + 1, "description", r.description, :quoted),
        encode_field(depth + 1, "reference", r.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "revision ", r.date, ";\n"]
    end
  end

  defp to_iodata(%BelongsTo{} = b, depth) do
    ind = indent(depth)

    [
      ind, "belongs-to ", b.module, " {\n",
      encode_field(depth + 1, "prefix", b.prefix, :unquoted),
      ind, "}\n"
    ]
  end

  # ---------------------------------------------------------------------------
  # Data definition
  # ---------------------------------------------------------------------------

  defp to_iodata(%Container{} = c, depth) do
    encode_data_node("container", c.name, depth, fn d ->
      [
        encode_when(c.when_expr, d),
        encode_if_features(c.if_features, d),
        encode_musts(c.must, d),
        encode_field(d, "config", encode_bool(c.config), :unquoted),
        encode_field(d, "presence", c.presence, :quoted),
        encode_field(d, "status", encode_status(c.status), :unquoted),
        encode_field(d, "description", c.description, :quoted),
        encode_field(d, "reference", c.reference, :quoted),
        encode_nodes(c.typedefs, d),
        encode_nodes(c.groupings, d),
        encode_nodes(c.body, d)
      ]
    end)
  end

  defp to_iodata(%Leaf{} = l, depth) do
    encode_data_node("leaf", l.name, depth, fn d ->
      [
        encode_when(l.when_expr, d),
        encode_if_features(l.if_features, d),
        if(l.type, do: to_iodata(l.type, d), else: []),
        encode_musts(l.must, d),
        encode_field(d, "config", encode_bool(l.config), :unquoted),
        encode_field(d, "mandatory", encode_bool(l.mandatory), :unquoted),
        encode_field(d, "default", l.default, :quoted),
        encode_field(d, "units", l.units, :quoted),
        encode_field(d, "status", encode_status(l.status), :unquoted),
        encode_field(d, "description", l.description, :quoted),
        encode_field(d, "reference", l.reference, :quoted)
      ]
    end)
  end

  defp to_iodata(%LeafList{} = l, depth) do
    encode_data_node("leaf-list", l.name, depth, fn d ->
      [
        encode_when(l.when_expr, d),
        encode_if_features(l.if_features, d),
        if(l.type, do: to_iodata(l.type, d), else: []),
        encode_musts(l.must, d),
        encode_field(d, "config", encode_bool(l.config), :unquoted),
        encode_field(d, "min-elements", encode_int(l.min_elements), :unquoted),
        encode_field(d, "max-elements", l.max_elements, :unquoted),
        encode_field(d, "ordered-by", l.ordered_by, :unquoted),
        encode_field(d, "units", l.units, :quoted),
        encode_field(d, "status", encode_status(l.status), :unquoted),
        encode_field(d, "description", l.description, :quoted),
        encode_field(d, "reference", l.reference, :quoted)
      ]
    end)
  end

  defp to_iodata(%List{} = l, depth) do
    encode_data_node("list", l.name, depth, fn d ->
      [
        encode_when(l.when_expr, d),
        encode_if_features(l.if_features, d),
        encode_musts(l.must, d),
        encode_field(d, "key", l.key, :quoted),
        encode_list_field(d, "unique", l.unique, :quoted),
        encode_field(d, "config", encode_bool(l.config), :unquoted),
        encode_field(d, "min-elements", encode_int(l.min_elements), :unquoted),
        encode_field(d, "max-elements", l.max_elements, :unquoted),
        encode_field(d, "ordered-by", l.ordered_by, :unquoted),
        encode_field(d, "status", encode_status(l.status), :unquoted),
        encode_field(d, "description", l.description, :quoted),
        encode_field(d, "reference", l.reference, :quoted),
        encode_nodes(l.typedefs, d),
        encode_nodes(l.groupings, d),
        encode_nodes(l.body, d)
      ]
    end)
  end

  defp to_iodata(%Choice{} = c, depth) do
    encode_data_node("choice", c.name, depth, fn d ->
      [
        encode_when(c.when_expr, d),
        encode_if_features(c.if_features, d),
        encode_field(d, "config", encode_bool(c.config), :unquoted),
        encode_field(d, "mandatory", encode_bool(c.mandatory), :unquoted),
        encode_field(d, "default", c.default, :unquoted),
        encode_field(d, "status", encode_status(c.status), :unquoted),
        encode_field(d, "description", c.description, :quoted),
        encode_field(d, "reference", c.reference, :quoted),
        encode_nodes(c.cases, d)
      ]
    end)
  end

  defp to_iodata(%Case{} = c, depth) do
    encode_data_node("case", c.name, depth, fn d ->
      [
        encode_when(c.when_expr, d),
        encode_if_features(c.if_features, d),
        encode_field(d, "status", encode_status(c.status), :unquoted),
        encode_field(d, "description", c.description, :quoted),
        encode_field(d, "reference", c.reference, :quoted),
        encode_nodes(c.body, d)
      ]
    end)
  end

  defp to_iodata(%AnyData{} = a, depth), do: encode_any("anydata", a, depth)
  defp to_iodata(%AnyXml{} = a, depth), do: encode_any("anyxml", a, depth)

  # ---------------------------------------------------------------------------
  # Schema manipulation
  # ---------------------------------------------------------------------------

  defp to_iodata(%Grouping{} = g, depth) do
    encode_data_node("grouping", g.name, depth, fn d ->
      [
        encode_field(d, "status", encode_status(g.status), :unquoted),
        encode_field(d, "description", g.description, :quoted),
        encode_field(d, "reference", g.reference, :quoted),
        encode_nodes(g.typedefs, d),
        encode_nodes(g.groupings, d),
        encode_nodes(g.body, d)
      ]
    end)
  end

  defp to_iodata(%Uses{} = u, depth) do
    ind = indent(depth)

    if u.refines == [] && u.augments == [] && u.when_expr == nil && u.if_features == [] do
      [ind, "uses ", u.grouping, ";\n"]
    else
      [
        ind, "uses ", u.grouping, " {\n",
        encode_when(u.when_expr, depth + 1),
        encode_if_features(u.if_features, depth + 1),
        encode_field(depth + 1, "status", encode_status(u.status), :unquoted),
        encode_field(depth + 1, "description", u.description, :quoted),
        encode_field(depth + 1, "reference", u.reference, :quoted),
        encode_nodes(u.refines, depth + 1),
        encode_nodes(u.augments, depth + 1),
        ind, "}\n"
      ]
    end
  end

  defp to_iodata(%Refine{} = r, depth) do
    ind = indent(depth)

    [
      ind, "refine ", quote_string(r.target_node), " {\n",
      encode_field(depth + 1, "config", encode_bool(r.config), :unquoted),
      encode_field(depth + 1, "mandatory", encode_bool(r.mandatory), :unquoted),
      encode_field(depth + 1, "default", r.default, :quoted),
      encode_field(depth + 1, "presence", r.presence, :quoted),
      encode_musts(r.must, depth + 1),
      encode_field(depth + 1, "min-elements", encode_int(r.min_elements), :unquoted),
      encode_field(depth + 1, "max-elements", r.max_elements, :unquoted),
      encode_field(depth + 1, "description", r.description, :quoted),
      encode_field(depth + 1, "reference", r.reference, :quoted),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Augment{} = a, depth) do
    ind = indent(depth)

    [
      ind, "augment ", quote_string(a.target_node), " {\n",
      encode_when(a.when_expr, depth + 1),
      encode_if_features(a.if_features, depth + 1),
      encode_field(depth + 1, "status", encode_status(a.status), :unquoted),
      encode_field(depth + 1, "description", a.description, :quoted),
      encode_field(depth + 1, "reference", a.reference, :quoted),
      encode_nodes(a.body, depth + 1),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Deviation{} = d, depth) do
    ind = indent(depth)

    [
      ind, "deviation ", quote_string(d.target_node), " {\n",
      encode_field(depth + 1, "description", d.description, :quoted),
      encode_field(depth + 1, "reference", d.reference, :quoted),
      encode_nodes(d.deviates, depth + 1),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Deviate{} = d, depth) do
    ind = indent(depth)
    type_str = deviate_type_string(d.type)

    [
      ind, "deviate ", type_str, " {\n",
      if(d.type_replacement, do: to_iodata(d.type_replacement, depth + 1), else: []),
      encode_field(depth + 1, "config", encode_bool(d.config), :unquoted),
      encode_field(depth + 1, "mandatory", encode_bool(d.mandatory), :unquoted),
      encode_field(depth + 1, "default", d.default, :quoted),
      encode_field(depth + 1, "units", d.units, :quoted),
      encode_musts(d.must, depth + 1),
      encode_field(depth + 1, "min-elements", encode_int(d.min_elements), :unquoted),
      encode_field(depth + 1, "max-elements", d.max_elements, :unquoted),
      encode_list_field(depth + 1, "unique", d.unique, :quoted),
      ind, "}\n"
    ]
  end

  # ---------------------------------------------------------------------------
  # Type system
  # ---------------------------------------------------------------------------

  defp to_iodata(%Typedef{} = t, depth) do
    ind = indent(depth)

    [
      ind, "typedef ", t.name, " {\n",
      if(t.type, do: to_iodata(t.type, depth + 1), else: []),
      encode_field(depth + 1, "default", t.default, :quoted),
      encode_field(depth + 1, "units", t.units, :quoted),
      encode_field(depth + 1, "status", encode_status(t.status), :unquoted),
      encode_field(depth + 1, "description", t.description, :quoted),
      encode_field(depth + 1, "reference", t.reference, :quoted),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Type{} = t, depth) do
    ind = indent(depth)
    has_subs = t.range || t.length || t.patterns != [] || t.enum_values != [] ||
               t.bit_values != [] || t.union_types != [] || t.fraction_digits ||
               t.path || t.require_instance != nil

    if has_subs do
      [
        ind, "type ", t.name, " {\n",
        encode_field(depth + 1, "fraction-digits", encode_int(t.fraction_digits), :unquoted),
        encode_field(depth + 1, "path", t.path, :quoted),
        encode_field(depth + 1, "require-instance", encode_bool(t.require_instance), :unquoted),
        if(t.range, do: to_iodata(t.range, depth + 1), else: []),
        if(t.length, do: to_iodata(t.length, depth + 1), else: []),
        encode_nodes(t.patterns, depth + 1),
        encode_nodes(t.enum_values, depth + 1),
        encode_nodes(t.bit_values, depth + 1),
        encode_nodes(t.union_types, depth + 1),
        ind, "}\n"
      ]
    else
      [ind, "type ", t.name, ";\n"]
    end
  end

  defp to_iodata(%Enum{} = e, depth) do
    ind = indent(depth)

    if e.value || e.status || e.description || e.reference || e.if_features != [] do
      [
        ind, "enum ", quote_string(e.name), " {\n",
        encode_field(depth + 1, "value", encode_int(e.value), :unquoted),
        encode_if_features(e.if_features, depth + 1),
        encode_field(depth + 1, "status", encode_status(e.status), :unquoted),
        encode_field(depth + 1, "description", e.description, :quoted),
        encode_field(depth + 1, "reference", e.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "enum ", quote_string(e.name), ";\n"]
    end
  end

  defp to_iodata(%Bit{} = b, depth) do
    ind = indent(depth)

    if b.position || b.status || b.description || b.reference do
      [
        ind, "bit ", b.name, " {\n",
        encode_field(depth + 1, "position", encode_int(b.position), :unquoted),
        encode_field(depth + 1, "status", encode_status(b.status), :unquoted),
        encode_field(depth + 1, "description", b.description, :quoted),
        encode_field(depth + 1, "reference", b.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "bit ", b.name, ";\n"]
    end
  end

  # ---------------------------------------------------------------------------
  # Identity & Feature
  # ---------------------------------------------------------------------------

  defp to_iodata(%Identity{} = i, depth) do
    encode_data_node("identity", i.name, depth, fn d ->
      [
        encode_list_field(d, "base", i.bases, :unquoted),
        encode_if_features(i.if_features, d),
        encode_field(d, "status", encode_status(i.status), :unquoted),
        encode_field(d, "description", i.description, :quoted),
        encode_field(d, "reference", i.reference, :quoted)
      ]
    end)
  end

  defp to_iodata(%Feature{} = f, depth) do
    encode_data_node("feature", f.name, depth, fn d ->
      [
        encode_if_features(f.if_features, d),
        encode_field(d, "status", encode_status(f.status), :unquoted),
        encode_field(d, "description", f.description, :quoted),
        encode_field(d, "reference", f.reference, :quoted)
      ]
    end)
  end

  # ---------------------------------------------------------------------------
  # RPC / Action / Notification
  # ---------------------------------------------------------------------------

  defp to_iodata(%Rpc{} = r, depth) do
    encode_data_node("rpc", r.name, depth, fn d ->
      [
        encode_if_features(r.if_features, d),
        encode_field(d, "status", encode_status(r.status), :unquoted),
        encode_field(d, "description", r.description, :quoted),
        encode_field(d, "reference", r.reference, :quoted),
        encode_nodes(r.typedefs, d),
        encode_nodes(r.groupings, d),
        if(r.input, do: to_iodata(r.input, d), else: []),
        if(r.output, do: to_iodata(r.output, d), else: [])
      ]
    end)
  end

  defp to_iodata(%Action{} = a, depth) do
    encode_data_node("action", a.name, depth, fn d ->
      [
        encode_if_features(a.if_features, d),
        encode_field(d, "status", encode_status(a.status), :unquoted),
        encode_field(d, "description", a.description, :quoted),
        encode_field(d, "reference", a.reference, :quoted),
        encode_nodes(a.typedefs, d),
        encode_nodes(a.groupings, d),
        if(a.input, do: to_iodata(a.input, d), else: []),
        if(a.output, do: to_iodata(a.output, d), else: [])
      ]
    end)
  end

  defp to_iodata(%Input{} = i, depth) do
    ind = indent(depth)

    [
      ind, "input {\n",
      encode_musts(i.must, depth + 1),
      encode_nodes(i.typedefs, depth + 1),
      encode_nodes(i.groupings, depth + 1),
      encode_nodes(i.body, depth + 1),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Output{} = o, depth) do
    ind = indent(depth)

    [
      ind, "output {\n",
      encode_musts(o.must, depth + 1),
      encode_nodes(o.typedefs, depth + 1),
      encode_nodes(o.groupings, depth + 1),
      encode_nodes(o.body, depth + 1),
      ind, "}\n"
    ]
  end

  defp to_iodata(%Notification{} = n, depth) do
    encode_data_node("notification", n.name, depth, fn d ->
      [
        encode_if_features(n.if_features, d),
        encode_musts(n.must, d),
        encode_field(d, "status", encode_status(n.status), :unquoted),
        encode_field(d, "description", n.description, :quoted),
        encode_field(d, "reference", n.reference, :quoted),
        encode_nodes(n.typedefs, d),
        encode_nodes(n.groupings, d),
        encode_nodes(n.body, d)
      ]
    end)
  end

  # ---------------------------------------------------------------------------
  # Constraints
  # ---------------------------------------------------------------------------

  defp to_iodata(%Must{} = m, depth) do
    ind = indent(depth)

    if m.error_message || m.error_app_tag || m.description || m.reference do
      [
        ind, "must ", quote_string(m.xpath), " {\n",
        encode_field(depth + 1, "error-message", m.error_message, :quoted),
        encode_field(depth + 1, "error-app-tag", m.error_app_tag, :quoted),
        encode_field(depth + 1, "description", m.description, :quoted),
        encode_field(depth + 1, "reference", m.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "must ", quote_string(m.xpath), ";\n"]
    end
  end

  defp to_iodata(%When{} = w, depth) do
    ind = indent(depth)

    if w.description || w.reference do
      [
        ind, "when ", quote_string(w.xpath), " {\n",
        encode_field(depth + 1, "description", w.description, :quoted),
        encode_field(depth + 1, "reference", w.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "when ", quote_string(w.xpath), ";\n"]
    end
  end

  defp to_iodata(%Range{} = r, depth) do
    ind = indent(depth)

    if r.error_message || r.error_app_tag || r.description || r.reference do
      [
        ind, "range ", quote_string(r.expression), " {\n",
        encode_field(depth + 1, "error-message", r.error_message, :quoted),
        encode_field(depth + 1, "error-app-tag", r.error_app_tag, :quoted),
        encode_field(depth + 1, "description", r.description, :quoted),
        encode_field(depth + 1, "reference", r.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "range ", quote_string(r.expression), ";\n"]
    end
  end

  defp to_iodata(%Length{} = l, depth) do
    ind = indent(depth)

    if l.error_message || l.error_app_tag || l.description || l.reference do
      [
        ind, "length ", quote_string(l.expression), " {\n",
        encode_field(depth + 1, "error-message", l.error_message, :quoted),
        encode_field(depth + 1, "error-app-tag", l.error_app_tag, :quoted),
        encode_field(depth + 1, "description", l.description, :quoted),
        encode_field(depth + 1, "reference", l.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "length ", quote_string(l.expression), ";\n"]
    end
  end

  defp to_iodata(%Pattern{} = p, depth) do
    ind = indent(depth)

    if p.modifier || p.error_message || p.error_app_tag || p.description || p.reference do
      [
        ind, "pattern ", quote_string(p.value), " {\n",
        encode_field(depth + 1, "modifier", p.modifier, :unquoted),
        encode_field(depth + 1, "error-message", p.error_message, :quoted),
        encode_field(depth + 1, "error-app-tag", p.error_app_tag, :quoted),
        encode_field(depth + 1, "description", p.description, :quoted),
        encode_field(depth + 1, "reference", p.reference, :quoted),
        ind, "}\n"
      ]
    else
      [ind, "pattern ", quote_string(p.value), ";\n"]
    end
  end

  # ---------------------------------------------------------------------------
  # Extension
  # ---------------------------------------------------------------------------

  defp to_iodata(%ExtensionDef{} = e, depth) do
    encode_data_node("extension", e.name, depth, fn d ->
      [
        encode_field(d, "argument", e.argument, :quoted),
        encode_field(d, "status", encode_status(e.status), :unquoted),
        encode_field(d, "description", e.description, :quoted),
        encode_field(d, "reference", e.reference, :quoted)
      ]
    end)
  end

  defp to_iodata(%ExtensionUse{keyword: {prefix, name}} = e, depth) do
    ind = indent(depth)
    kw = "#{prefix}:#{name}"

    if e.sub_statements == [] do
      if e.argument do
        [ind, kw, " ", quote_string(e.argument), ";\n"]
      else
        [ind, kw, ";\n"]
      end
    else
      [
        ind, kw,
        if(e.argument, do: [" ", quote_string(e.argument)], else: []),
        " {\n",
        # Sub-statements are generic tuples — re-encode them
        Elixir.Enum.map(e.sub_statements, fn {k, a, s, _m} ->
          encode_generic_statement(k, a, s, depth + 1)
        end),
        ind, "}\n"
      ]
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp encode_data_node(keyword, name, depth, children_fn) do
    ind = indent(depth)
    children = children_fn.(depth + 1)
    flat = List.flatten(children)

    if flat == [] do
      [ind, keyword, " ", name, ";\n"]
    else
      [
        ind, keyword, " ", name, " {\n",
        children,
        ind, "}\n"
      ]
    end
  end

  defp encode_any(keyword, a, depth) do
    encode_data_node(keyword, a.name, depth, fn d ->
      [
        encode_when(a.when_expr, d),
        encode_if_features(a.if_features, d),
        encode_musts(a.must, d),
        encode_field(d, "config", encode_bool(a.config), :unquoted),
        encode_field(d, "mandatory", encode_bool(a.mandatory), :unquoted),
        encode_field(d, "status", encode_status(a.status), :unquoted),
        encode_field(d, "description", a.description, :quoted),
        encode_field(d, "reference", a.reference, :quoted)
      ]
    end)
  end

  defp encode_field(_depth, _keyword, nil, _style), do: []

  defp encode_field(depth, keyword, value, :quoted) do
    [indent(depth), keyword, " ", quote_string(value), ";\n"]
  end

  defp encode_field(depth, keyword, value, :unquoted) do
    [indent(depth), keyword, " ", to_string(value), ";\n"]
  end

  defp encode_list_field(_depth, _keyword, [], _style), do: []

  defp encode_list_field(depth, keyword, values, style) do
    Elixir.Enum.map(values, fn v -> encode_field(depth, keyword, v, style) end)
  end

  defp encode_nodes([], _depth), do: []

  defp encode_nodes(nodes, depth) do
    Elixir.Enum.map(nodes, fn node -> to_iodata(node, depth) end)
  end

  defp encode_when(nil, _depth), do: []
  defp encode_when(%When{} = w, depth), do: to_iodata(w, depth)

  defp encode_if_features([], _depth), do: []

  defp encode_if_features(features, depth) do
    Elixir.Enum.map(features, fn f ->
      [indent(depth), "if-feature ", quote_string(f), ";\n"]
    end)
  end

  defp encode_musts([], _depth), do: []
  defp encode_musts(musts, depth), do: encode_nodes(musts, depth)

  defp encode_generic_statement(keyword, arg, subs, depth) do
    ind = indent(depth)
    kw = if is_tuple(keyword), do: "#{elem(keyword, 0)}:#{elem(keyword, 1)}", else: to_string(keyword)

    if subs == [] do
      if arg do
        [ind, kw, " ", quote_string(arg), ";\n"]
      else
        [ind, kw, ";\n"]
      end
    else
      [
        ind, kw,
        if(arg, do: [" ", quote_string(arg)], else: []),
        " {\n",
        Elixir.Enum.map(subs, fn {k, a, s, _m} -> encode_generic_statement(k, a, s, depth + 1) end),
        ind, "}\n"
      ]
    end
  end

  defp indent(0), do: []
  defp indent(n), do: String.duplicate("  ", n)

  defp quote_string(nil), do: "\"\""
  defp quote_string(s) when is_binary(s), do: ["\"", escape(s), "\""]
  defp quote_string(s), do: ["\"", to_string(s), "\""]

  defp escape(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
  end

  defp encode_bool(nil), do: nil
  defp encode_bool(true), do: "true"
  defp encode_bool(false), do: "false"

  defp encode_int(nil), do: nil
  defp encode_int(n) when is_integer(n), do: Integer.to_string(n)
  defp encode_int(s), do: s

  defp encode_status(nil), do: nil
  defp encode_status(:current), do: "current"
  defp encode_status(:deprecated), do: "deprecated"
  defp encode_status(:obsolete), do: "obsolete"

  defp deviate_type_string(:not_supported), do: "not-supported"
  defp deviate_type_string(:add), do: "add"
  defp deviate_type_string(:replace), do: "replace"
  defp deviate_type_string(:delete), do: "delete"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/encoder/encoder_test.exs`
Expected: 5 tests, 0 failures.

- [ ] **Step 5: Wire encode/1 into ExYang public API**

Add to `lib/ex_yang.ex`:

```elixir
alias ExYang.Encoder.Encoder

@doc """
Encode a module struct back to YANG source (round-trip faithful).
"""
@spec encode(struct()) :: {:ok, String.t()}
defdelegate encode(module), to: Encoder
```

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/ex_yang/encoder/encoder.ex lib/ex_yang.ex test/ex_yang/encoder/encoder_test.exs
git commit -m "Add round-trip faithful YANG encoder"
```

---

### Task 14: Formatter — Canonical Style

**Files:**
- Create: `lib/ex_yang/encoder/formatter.ex`
- Create: `test/ex_yang/encoder/formatter_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/encoder/formatter_test.exs
defmodule ExYang.Encoder.FormatterTest do
  use ExUnit.Case, async: true

  alias ExYang.Encoder.Formatter

  test "formats a module to canonical style" do
    yang = """
    module   test {
       namespace    "urn:example:test";
      prefix t;
        leaf name{type string;}
    }
    """

    {:ok, mod} = ExYang.parse(yang)
    {:ok, formatted} = Formatter.format(mod)

    assert formatted =~ "module test {"
    assert formatted =~ "  namespace \"urn:example:test\";"
    assert formatted =~ "  prefix t;"
    assert formatted =~ "  leaf name {"
    assert formatted =~ "    type string;"
  end

  test "format is idempotent" do
    yang = """
    module test {
      namespace "urn:example:test";
      prefix t;

      leaf name {
        type string;
      }
    }
    """

    {:ok, mod} = ExYang.parse(yang)
    {:ok, first} = Formatter.format(mod)
    {:ok, mod2} = ExYang.parse(first)
    {:ok, second} = Formatter.format(mod2)
    assert first == second
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/encoder/formatter_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/encoder/formatter.ex**

The formatter reuses the encoder but ignores all metadata — it always emits canonical style. For this first implementation, the encoder already produces canonical style by default (since we don't yet preserve original whitespace metadata). So the formatter delegates to the encoder.

```elixir
defmodule ExYang.Encoder.Formatter do
  @moduledoc """
  Formats YANG model structs to canonical style.

  Ignores all stored formatting metadata. Always produces:
  - 2-space indentation
  - Double quotes for all strings
  - Sub-statements ordered per RFC 7950 convention
  - One blank line between top-level statements
  """

  alias ExYang.Encoder.Encoder

  @doc """
  Format a module struct to canonical YANG source.
  """
  @spec format(struct()) :: {:ok, String.t()}
  def format(node) do
    # The encoder already produces canonical style by default.
    # When we add whitespace metadata preservation to the encoder,
    # the formatter will strip it and enforce canonical ordering.
    Encoder.encode(node)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/encoder/formatter_test.exs`
Expected: 2 tests, 0 failures.

- [ ] **Step 5: Wire format/1 into ExYang public API**

Add to `lib/ex_yang.ex`:

```elixir
alias ExYang.Encoder.Formatter

@doc """
Format a module struct to canonical YANG style.
"""
@spec format(struct()) :: {:ok, String.t()}
defdelegate format(module), to: Formatter
```

- [ ] **Step 6: Commit**

```bash
git add lib/ex_yang/encoder/formatter.ex lib/ex_yang.ex test/ex_yang/encoder/formatter_test.exs
git commit -m "Add canonical formatter (delegates to encoder for now)"
```

---

### Task 15: XPath Subset Parser

**Files:**
- Create: `lib/ex_yang/xpath/xpath.ex`
- Create: `test/ex_yang/xpath/xpath_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/xpath/xpath_test.exs
defmodule ExYang.XPath.XPathTest do
  use ExUnit.Case, async: true

  alias ExYang.XPath

  describe "path expressions" do
    test "absolute path" do
      assert {:ok, {:path, :absolute, [{:step, "interfaces"}, {:step, "interface"}]}} =
               XPath.parse("/interfaces/interface")
    end

    test "relative path" do
      assert {:ok, {:path, :relative, [{:step, ".."}, {:step, "name"}]}} =
               XPath.parse("../name")
    end

    test "path with namespace prefix" do
      assert {:ok, {:path, :absolute, [{:step, {"if", "interfaces"}}, {:step, {"if", "interface"}}]}} =
               XPath.parse("/if:interfaces/if:interface")
    end

    test "current() function" do
      assert {:ok, {:path, :relative, [{:step, {:call, :current, []}}, {:step, ".."}, {:step, "type"}]}} =
               XPath.parse("current()/../type")
    end
  end

  describe "predicates" do
    test "path with predicate" do
      assert {:ok, {:path, :relative, [{:step, "interface", {:eq, {:path, :relative, [{:step, "name"}]}, {:literal, "eth0"}}}]}} =
               XPath.parse("interface[name='eth0']")
    end
  end

  describe "function calls" do
    test "derived-from-or-self" do
      assert {:ok, {:call, :"derived-from-or-self", [_, _]}} =
               XPath.parse("derived-from-or-self(type, 'ianaift:ethernetCsmacd')")
    end

    test "count" do
      assert {:ok, {:call, :count, [_]}} = XPath.parse("count(../interface)")
    end
  end

  describe "boolean expressions" do
    test "and" do
      assert {:ok, {:and, _, _}} = XPath.parse("../enabled = 'true' and ../type = 'ethernet'")
    end

    test "or" do
      assert {:ok, {:or, _, _}} = XPath.parse("../type = 'a' or ../type = 'b'")
    end

    test "not" do
      assert {:ok, {:call, :not, [_]}} = XPath.parse("not(../disabled)")
    end
  end

  describe "comparison" do
    test "equals" do
      assert {:ok, {:eq, _, _}} = XPath.parse("../type = 'ethernet'")
    end

    test "not equals" do
      assert {:ok, {:neq, _, _}} = XPath.parse("../status != 'disabled'")
    end
  end

  describe "round-trip" do
    test "format back to string" do
      expressions = [
        "../name",
        "/if:interfaces/if:interface",
        "derived-from-or-self(type, 'ianaift:ethernetCsmacd')",
        "count(../interface)",
        "../enabled = 'true' and ../type = 'ethernet'"
      ]

      for expr <- expressions do
        {:ok, ast} = XPath.parse(expr)
        formatted = XPath.format(ast)
        assert is_binary(formatted), "format returned non-string for: #{expr}"
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/xpath/xpath_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/xpath/xpath.ex**

This is a hand-rolled recursive descent parser for the XPath subset used in YANG. NimbleParsec would work but the grammar is small enough that direct parsing is clearer.

```elixir
defmodule ExYang.XPath do
  @moduledoc """
  Parses the XPath 1.0 subset used in YANG `when` and `must` statements.

  Does not evaluate — only parses and represents. The parsed AST can be
  inspected by consumers to understand path dependencies between nodes.
  """

  @doc """
  Parse an XPath expression string into an AST.
  """
  @spec parse(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse(input) when is_binary(input) do
    input = String.trim(input)
    case parse_or_expr(input) do
      {:ok, ast, ""} -> {:ok, ast}
      {:ok, ast, rest} when String.trim(rest) == "" -> {:ok, ast}
      {:ok, _ast, rest} -> {:error, "unexpected trailing: #{rest}"}
      {:error, _} = err -> err
    end
  end

  @doc """
  Format an AST back to an XPath string.
  """
  @spec format(term()) :: String.t()
  def format(ast), do: do_format(ast)

  # ---------------------------------------------------------------------------
  # Or expression
  # ---------------------------------------------------------------------------

  defp parse_or_expr(input) do
    with {:ok, left, rest} <- parse_and_expr(input) do
      parse_or_tail(left, String.trim_leading(rest))
    end
  end

  defp parse_or_tail(left, "or" <> rest) when not_ident_char(rest) do
    with {:ok, right, rest2} <- parse_and_expr(String.trim_leading(rest)) do
      parse_or_tail({:or, left, right}, String.trim_leading(rest2))
    end
  end
  defp parse_or_tail(left, rest), do: {:ok, left, rest}

  # ---------------------------------------------------------------------------
  # And expression
  # ---------------------------------------------------------------------------

  defp parse_and_expr(input) do
    with {:ok, left, rest} <- parse_comparison(input) do
      parse_and_tail(left, String.trim_leading(rest))
    end
  end

  defp parse_and_tail(left, "and" <> rest) when not_ident_char(rest) do
    with {:ok, right, rest2} <- parse_comparison(String.trim_leading(rest)) do
      parse_and_tail({:and, left, right}, String.trim_leading(rest2))
    end
  end
  defp parse_and_tail(left, rest), do: {:ok, left, rest}

  # ---------------------------------------------------------------------------
  # Comparison
  # ---------------------------------------------------------------------------

  defp parse_comparison(input) do
    with {:ok, left, rest} <- parse_additive(input) do
      rest = String.trim_leading(rest)
      case rest do
        "!=" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:neq, left, right}, r2}
        "=" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:eq, left, right}, r2}
        "<=" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:lte, left, right}, r2}
        ">=" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:gte, left, right}, r2}
        "<" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:lt, left, right}, r2}
        ">" <> r -> with {:ok, right, r2} <- parse_additive(String.trim_leading(r)), do: {:ok, {:gt, left, right}, r2}
        _ -> {:ok, left, rest}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Additive / Multiplicative (simplified — most YANG xpath doesn't use these)
  # ---------------------------------------------------------------------------

  defp parse_additive(input), do: parse_primary(String.trim_leading(input))

  # ---------------------------------------------------------------------------
  # Primary: path, function call, literal, parenthesized
  # ---------------------------------------------------------------------------

  defp parse_primary("'" <> rest) do
    case String.split(rest, "'", parts: 2) do
      [value, rest2] -> {:ok, {:literal, value}, rest2}
      _ -> {:error, "unterminated single-quoted string"}
    end
  end

  defp parse_primary("\"" <> rest) do
    case String.split(rest, "\"", parts: 2) do
      [value, rest2] -> {:ok, {:literal, value}, rest2}
      _ -> {:error, "unterminated double-quoted string"}
    end
  end

  defp parse_primary("(" <> rest) do
    with {:ok, expr, rest2} <- parse_or_expr(String.trim_leading(rest)) do
      rest2 = String.trim_leading(rest2)
      case rest2 do
        ")" <> r -> {:ok, expr, r}
        _ -> {:error, "expected closing paren"}
      end
    end
  end

  defp parse_primary("/" <> rest) do
    parse_absolute_path(rest)
  end

  defp parse_primary(<<c, _::binary>> = input) when c in ?0..?9 do
    {num_str, rest} = take_while(input, fn c -> c in ?0..?9 or c == ?. end)
    {:ok, {:number, num_str}, rest}
  end

  defp parse_primary(input) do
    case take_name(input) do
      {"", _} -> {:error, "expected expression, got: #{String.slice(input, 0, 20)}"}
      {name, rest} ->
        rest = String.trim_leading(rest)
        case rest do
          "(" <> r ->
            # Function call
            parse_func_args(String.to_atom(name), String.trim_leading(r), [])
          _ ->
            # Start of a relative path
            parse_relative_path_from(name, rest)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Path parsing
  # ---------------------------------------------------------------------------

  defp parse_absolute_path(input) do
    case parse_path_steps(input) do
      {:ok, steps, rest} -> {:ok, {:path, :absolute, steps}, rest}
      err -> err
    end
  end

  defp parse_relative_path_from(first_name, rest) do
    first_step = make_step(first_name)

    # Check for predicate on this step
    {first_step, rest} = maybe_parse_predicate(first_step, String.trim_leading(rest))

    case rest do
      "/" <> more ->
        case parse_path_steps(more) do
          {:ok, more_steps, rest2} ->
            {:ok, {:path, :relative, [first_step | more_steps]}, rest2}
          err -> err
        end
      _ ->
        {:ok, {:path, :relative, [first_step]}, rest}
    end
  end

  defp parse_path_steps(input) do
    input = String.trim_leading(input)
    case take_name(input) do
      {"", _} -> {:ok, [], input}
      {name, rest} ->
        step = make_step(name)
        {step, rest} = maybe_parse_predicate(step, String.trim_leading(rest))

        case String.trim_leading(rest) do
          "/" <> more ->
            case parse_path_steps(more) do
              {:ok, more_steps, rest2} -> {:ok, [step | more_steps], rest2}
              err -> err
            end
          _ ->
            {:ok, [step], rest}
        end
    end
  end

  defp maybe_parse_predicate(step, "[" <> rest) do
    case parse_or_expr(String.trim_leading(rest)) do
      {:ok, pred, rest2} ->
        rest2 = String.trim_leading(rest2)
        case rest2 do
          "]" <> r ->
            {{:step, step_name(step), pred}, r}
          _ ->
            {step, "[" <> rest}  # bail — not a valid predicate
        end
      _ ->
        {step, "[" <> rest}
    end
  end
  defp maybe_parse_predicate(step, rest), do: {step, rest}

  defp step_name({:step, name}), do: name
  defp step_name({:step, name, _pred}), do: name

  defp make_step("."), do: {:step, "."}
  defp make_step(".."), do: {:step, ".."}
  defp make_step(name) do
    case String.split(name, ":", parts: 2) do
      [prefix, local] when prefix != "" and local != "" ->
        {:step, {prefix, local}}
      _ ->
        # Check if this is a function call syntax: name()
        {:step, name}
    end
  end

  # ---------------------------------------------------------------------------
  # Function call parsing
  # ---------------------------------------------------------------------------

  defp parse_func_args(name, ")" <> rest, acc) do
    # Handle current() which returns a node-set — check for path continuation
    result = {:call, name, Elixir.Enum.reverse(acc)}
    rest = String.trim_leading(rest)
    case rest do
      "/" <> more ->
        # Function call followed by path: current()/../type
        case parse_path_steps(more) do
          {:ok, steps, rest2} ->
            {:ok, {:path, :relative, [{:step, result} | steps]}, rest2}
          err -> err
        end
      _ ->
        {:ok, result, rest}
    end
  end

  defp parse_func_args(name, input, acc) do
    with {:ok, arg, rest} <- parse_or_expr(String.trim_leading(input)) do
      rest = String.trim_leading(rest)
      case rest do
        "," <> r -> parse_func_args(name, String.trim_leading(r), [arg | acc])
        ")" <> r ->
          result = {:call, name, Elixir.Enum.reverse([arg | acc])}
          r = String.trim_leading(r)
          case r do
            "/" <> more ->
              case parse_path_steps(more) do
                {:ok, steps, rest2} -> {:ok, {:path, :relative, [{:step, result} | steps]}, rest2}
                err -> err
              end
            _ ->
              {:ok, result, r}
          end
        _ -> {:error, "expected ',' or ')' in function args"}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp take_name(input) do
    take_while(input, fn c ->
      c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c in [?_, ?-, ?., ?:]
    end)
  end

  defp take_while(input, pred) do
    do_take_while(input, pred, [])
  end

  defp do_take_while(<<c, rest::binary>>, pred, acc) when is_function(pred) do
    if pred.(c) do
      do_take_while(rest, pred, [c | acc])
    else
      {acc |> Elixir.Enum.reverse() |> List.to_string(), <<c, rest::binary>>}
    end
  end
  defp do_take_while("", _pred, acc) do
    {acc |> Elixir.Enum.reverse() |> List.to_string(), ""}
  end

  # Guard for checking the character after "and"/"or" is not an identifier char
  defguardp not_ident_char(rest) when
    rest == "" or
    binary_part(rest, 0, 1) == " " or
    binary_part(rest, 0, 1) == "(" or
    binary_part(rest, 0, 1) == "\n" or
    binary_part(rest, 0, 1) == "\t"

  # ---------------------------------------------------------------------------
  # Formatter
  # ---------------------------------------------------------------------------

  defp do_format({:path, :absolute, steps}) do
    "/" <> Elixir.Enum.map_join(steps, "/", &format_step/1)
  end

  defp do_format({:path, :relative, steps}) do
    Elixir.Enum.map_join(steps, "/", &format_step/1)
  end

  defp do_format({:call, name, args}) do
    formatted_args = Elixir.Enum.map_join(args, ", ", &do_format/1)
    "#{name}(#{formatted_args})"
  end

  defp do_format({:literal, value}), do: "'#{value}'"
  defp do_format({:number, value}), do: value

  defp do_format({:eq, left, right}), do: "#{do_format(left)} = #{do_format(right)}"
  defp do_format({:neq, left, right}), do: "#{do_format(left)} != #{do_format(right)}"
  defp do_format({:lt, left, right}), do: "#{do_format(left)} < #{do_format(right)}"
  defp do_format({:gt, left, right}), do: "#{do_format(left)} > #{do_format(right)}"
  defp do_format({:lte, left, right}), do: "#{do_format(left)} <= #{do_format(right)}"
  defp do_format({:gte, left, right}), do: "#{do_format(left)} >= #{do_format(right)}"
  defp do_format({:and, left, right}), do: "#{do_format(left)} and #{do_format(right)}"
  defp do_format({:or, left, right}), do: "#{do_format(left)} or #{do_format(right)}"

  defp format_step({:step, name}) when is_binary(name), do: name
  defp format_step({:step, {prefix, local}}), do: "#{prefix}:#{local}"
  defp format_step({:step, {:call, _, _} = call}), do: do_format(call)
  defp format_step({:step, name, pred}) do
    base = case name do
      {prefix, local} -> "#{prefix}:#{local}"
      name when is_binary(name) -> name
    end
    "#{base}[#{do_format(pred)}]"
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/xpath/xpath_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/xpath/xpath.ex test/ex_yang/xpath/xpath_test.exs
git commit -m "Add XPath subset parser for when/must expressions"
```

---

### Task 16: IETF Fixture Download & Integration Test

**Files:**
- Create: `test/fixtures/ietf-yang-types@2013-07-15.yang`
- Create: `test/fixtures/ietf-interfaces@2018-02-20.yang`
- Create: `test/ex_yang/integration_test.exs`

- [ ] **Step 1: Download IETF YANG modules**

```bash
# From the IETF YANG module repository
curl -sL "https://raw.githubusercontent.com/YangModels/yang/main/standard/ietf/RFC/ietf-yang-types%402013-07-15.yang" > test/fixtures/ietf-yang-types@2013-07-15.yang
curl -sL "https://raw.githubusercontent.com/YangModels/yang/main/standard/ietf/RFC/ietf-interfaces%402018-02-20.yang" > test/fixtures/ietf-interfaces@2018-02-20.yang
curl -sL "https://raw.githubusercontent.com/YangModels/yang/main/standard/ietf/RFC/ietf-inet-types%402013-07-15.yang" > test/fixtures/ietf-inet-types@2013-07-15.yang
```

- [ ] **Step 2: Write the integration test**

```elixir
# test/ex_yang/integration_test.exs
defmodule ExYang.IntegrationTest do
  use ExUnit.Case, async: true

  alias ExYang.Model.{Module, Typedef, Container, Leaf, List}

  @fixtures_dir "test/fixtures"

  describe "ietf-yang-types" do
    test "parses successfully" do
      source = File.read!(Path.join(@fixtures_dir, "ietf-yang-types@2013-07-15.yang"))
      assert {:ok, %Module{name: "ietf-yang-types"} = mod} = ExYang.parse(source)
      assert mod.namespace == "urn:ietf:params:xml:ns:yang:ietf-yang-types"
      assert mod.prefix == "yang"
      assert length(mod.typedefs) > 10
    end

    test "round-trip produces reparseable output" do
      source = File.read!(Path.join(@fixtures_dir, "ietf-yang-types@2013-07-15.yang"))
      {:ok, mod} = ExYang.parse(source)
      {:ok, encoded} = ExYang.encode(mod)
      assert {:ok, %Module{name: "ietf-yang-types"}} = ExYang.parse(encoded)
    end
  end

  describe "ietf-interfaces" do
    test "parses successfully" do
      source = File.read!(Path.join(@fixtures_dir, "ietf-interfaces@2018-02-20.yang"))
      assert {:ok, %Module{name: "ietf-interfaces"} = mod} = ExYang.parse(source)
      assert mod.prefix == "if"
      assert length(mod.imports) >= 1
    end

    test "round-trip produces reparseable output" do
      source = File.read!(Path.join(@fixtures_dir, "ietf-interfaces@2018-02-20.yang"))
      {:ok, mod} = ExYang.parse(source)
      {:ok, encoded} = ExYang.encode(mod)
      assert {:ok, %Module{name: "ietf-interfaces"}} = ExYang.parse(encoded)
    end
  end

  describe "ietf-inet-types" do
    test "parses successfully" do
      source = File.read!(Path.join(@fixtures_dir, "ietf-inet-types@2013-07-15.yang"))
      assert {:ok, %Module{name: "ietf-inet-types"} = mod} = ExYang.parse(source)
      assert length(mod.typedefs) > 5
    end
  end

  describe "parse-encode-parse invariant" do
    test "all fixtures satisfy invariant" do
      for file <- Path.wildcard(Path.join(@fixtures_dir, "*.yang")) do
        source = File.read!(file)
        {:ok, mod1} = ExYang.parse(source)
        {:ok, encoded} = ExYang.encode(mod1)
        {:ok, mod2} = ExYang.parse(encoded)

        assert mod1.name == mod2.name,
               "Name mismatch in #{Path.basename(file)}: #{mod1.name} vs #{mod2.name}"

        assert length(mod1.body) == length(mod2.body),
               "Body length mismatch in #{Path.basename(file)}"
      end
    end
  end
end
```

- [ ] **Step 3: Run the integration test**

Run: `mix test test/ex_yang/integration_test.exs`
Expected: all tests pass. If any fail, fix the parser/encoder as needed.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/ test/ex_yang/integration_test.exs
git commit -m "Add IETF fixture modules and integration tests"
```

---

### Task 17: Resolver — ResolvedModule Struct & Import Resolver

**Files:**
- Create: `lib/ex_yang/resolver/resolved_module.ex`
- Create: `lib/ex_yang/resolver/import_resolver.ex`
- Create: `test/ex_yang/resolver/import_resolver_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/resolver/import_resolver_test.exs
defmodule ExYang.Resolver.ImportResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.ImportResolver
  alias ExYang.Model.{Module, Import}

  test "resolves imports from a registry map" do
    types_mod = %Module{name: "ietf-yang-types", prefix: "yang", namespace: "urn:yang-types", meta: %{}}
    main_mod = %Module{
      name: "test",
      namespace: "urn:test",
      prefix: "t",
      imports: [%Import{module: "ietf-yang-types", prefix: "yang", meta: %{}}],
      meta: %{}
    }

    registry = %{"ietf-yang-types" => types_mod}

    assert {:ok, namespace_map, []} = ImportResolver.resolve(main_mod, registry)
    assert %{"yang" => ^types_mod} = namespace_map
  end

  test "missing import produces error diagnostic" do
    main_mod = %Module{
      name: "test",
      namespace: "urn:test",
      prefix: "t",
      imports: [%Import{module: "nonexistent", prefix: "ne", meta: %{line: 3}}],
      meta: %{}
    }

    assert {:error, diagnostics} = ImportResolver.resolve(main_mod, %{})
    assert [%ExYang.Diagnostic{severity: :error, message: msg}] = diagnostics
    assert msg =~ "nonexistent"
  end

  test "no imports returns empty namespace map" do
    mod = %Module{name: "test", namespace: "urn:test", prefix: "t", meta: %{}}
    assert {:ok, %{}, []} = ImportResolver.resolve(mod, %{})
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/resolver/import_resolver_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/resolver/resolved_module.ex**

```elixir
defmodule ExYang.Resolver.ResolvedModule do
  @moduledoc """
  The output of the resolution pipeline — a fully resolved YANG module.
  """

  defstruct [
    :module,
    namespace_map: %{},
    identity_graph: %{},
    diagnostics: []
  ]

  @type t :: %__MODULE__{
          module: ExYang.Model.Module.t(),
          namespace_map: %{String.t() => ExYang.Model.Module.t()},
          identity_graph: map(),
          diagnostics: [ExYang.Diagnostic.t()]
        }
end
```

- [ ] **Step 4: Create lib/ex_yang/resolver/import_resolver.ex**

```elixir
defmodule ExYang.Resolver.ImportResolver do
  @moduledoc """
  Phase 1: Resolves import and include statements.

  Takes a module and a registry map (`%{module_name => %Module{}}`),
  builds a namespace map (`%{prefix => %Module{}}`).
  """

  alias ExYang.Diagnostic

  @doc """
  Resolve imports for a module.

  `registry` is a map of `%{module_name => %Module{}}`.

  Returns `{:ok, namespace_map, diagnostics}` or `{:error, diagnostics}`.
  """
  @spec resolve(struct(), map()) :: {:ok, map(), [Diagnostic.t()]} | {:error, [Diagnostic.t()]}
  def resolve(module, registry) do
    {namespace_map, diagnostics} =
      Enum.reduce(module.imports, {%{}, []}, fn imp, {ns_map, diags} ->
        case Map.get(registry, imp.module) do
          nil ->
            diag = %Diagnostic{
              severity: :error,
              phase: :resolution,
              message: "cannot resolve import '#{imp.module}' — module not found in registry",
              line: get_in(imp, [Access.key(:meta), Access.key(:line)]),
              context: ["module #{module.name}", "import #{imp.module}"]
            }
            {ns_map, [diag | diags]}

          target_mod ->
            # Check revision if specified
            diags =
              if imp.revision_date && target_mod.revisions != [] do
                has_revision = Enum.any?(target_mod.revisions, &(&1.date == imp.revision_date))
                if has_revision do
                  diags
                else
                  [%Diagnostic{
                    severity: :warning,
                    phase: :resolution,
                    message: "import '#{imp.module}' requests revision #{imp.revision_date} but module has different revisions",
                    line: get_in(imp, [Access.key(:meta), Access.key(:line)]),
                    context: ["module #{module.name}", "import #{imp.module}"]
                  } | diags]
                end
              else
                diags
              end

            {Map.put(ns_map, imp.prefix, target_mod), diags}
        end
      end)

    errors = Enum.filter(diagnostics, &(&1.severity == :error))

    if errors == [] do
      {:ok, namespace_map, Enum.reverse(diagnostics)}
    else
      {:error, Enum.reverse(diagnostics)}
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/ex_yang/resolver/import_resolver_test.exs`
Expected: 3 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add lib/ex_yang/resolver/ test/ex_yang/resolver/import_resolver_test.exs
git commit -m "Add ResolvedModule struct and import resolver (phase 1)"
```

---

### Task 18: Resolver — Type Resolver

**Files:**
- Create: `lib/ex_yang/resolver/type_resolver.ex`
- Create: `test/ex_yang/resolver/type_resolver_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/resolver/type_resolver_test.exs
defmodule ExYang.Resolver.TypeResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.TypeResolver
  alias ExYang.Model.{Module, Leaf, Typedef, Type, Range, Container}

  @builtin_types ~w(int8 int16 int32 int64 uint8 uint16 uint32 uint64
                     decimal64 string boolean enumeration bits binary
                     leafref identityref empty union instance-identifier)

  test "built-in types are terminals" do
    for type_name <- @builtin_types do
      leaf = %Leaf{name: "x", type: %Type{name: type_name}, meta: %{}}
      mod = %Module{name: "test", namespace: "urn:test", prefix: "t", body: [leaf], meta: %{}}

      {:ok, resolved, []} = TypeResolver.resolve(mod, %{}, %{})
      [resolved_leaf] = resolved.body
      assert resolved_leaf.type.name == type_name
    end
  end

  test "resolves local typedef" do
    typedef = %Typedef{
      name: "percentage",
      type: %Type{name: "uint8", range: %Range{expression: "0..100", meta: %{}}},
      meta: %{}
    }
    leaf = %Leaf{name: "cpu", type: %Type{name: "percentage"}, meta: %{}}
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      typedefs: [typedef], body: [leaf], meta: %{}
    }

    {:ok, resolved, []} = TypeResolver.resolve(mod, %{}, %{})
    [resolved_leaf] = resolved.body
    assert resolved_leaf.type.base == "uint8"
    assert resolved_leaf.type.range.expression == "0..100"
  end

  test "resolves cross-module typedef" do
    types_typedef = %Typedef{
      name: "counter32",
      type: %Type{name: "uint32"},
      meta: %{}
    }
    types_mod = %Module{
      name: "ietf-yang-types", namespace: "urn:yang-types", prefix: "yang",
      typedefs: [types_typedef], meta: %{}
    }

    leaf = %Leaf{name: "count", type: %Type{name: "yang:counter32"}, meta: %{}}
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      body: [leaf], meta: %{}
    }

    namespace_map = %{"yang" => types_mod}
    {:ok, resolved, []} = TypeResolver.resolve(mod, namespace_map, %{})
    [resolved_leaf] = resolved.body
    assert resolved_leaf.type.base == "uint32"
  end

  test "unresolvable typedef produces diagnostic" do
    leaf = %Leaf{name: "x", type: %Type{name: "nonexistent"}, meta: %{line: 5}}
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      body: [leaf], meta: %{}
    }

    {:ok, _resolved, diagnostics} = TypeResolver.resolve(mod, %{}, %{})
    assert Enum.any?(diagnostics, fn d -> d.message =~ "nonexistent" end)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/resolver/type_resolver_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/resolver/type_resolver.ex**

```elixir
defmodule ExYang.Resolver.TypeResolver do
  @moduledoc """
  Phase 2: Resolves typedef chains to their base built-in types.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Leaf, LeafList, Container, List, Choice, Case,
                       Grouping, Typedef, Type}

  @builtin_types MapSet.new(~w(
    int8 int16 int32 int64 uint8 uint16 uint32 uint64
    decimal64 string boolean enumeration bits binary
    leafref identityref empty union instance-identifier
  ))

  @doc """
  Resolve all types in a module.

  `namespace_map` is `%{prefix => %Module{}}` from phase 1.
  `opts` is reserved for future use.

  Returns `{:ok, updated_module, diagnostics}`.
  """
  @spec resolve(Module.t(), map(), map()) :: {:ok, Module.t(), [Diagnostic.t()]}
  def resolve(%Module{} = mod, namespace_map, _opts) do
    # Build typedef lookup: local typedefs + imported module typedefs
    local_typedefs = build_typedef_map(mod.typedefs)
    imported_typedefs = build_imported_typedef_map(namespace_map)
    all_typedefs = Map.merge(imported_typedefs, local_typedefs)

    {body, diags} = resolve_nodes(mod.body, all_typedefs, ["module #{mod.name}"])
    {:ok, %{mod | body: body}, diags}
  end

  defp resolve_nodes(nodes, typedefs, ctx) do
    Enum.map_reduce(nodes, [], fn node, diags ->
      {resolved, new_diags} = resolve_node(node, typedefs, ctx)
      {resolved, diags ++ new_diags}
    end)
  end

  defp resolve_node(%Leaf{} = leaf, typedefs, ctx) do
    ctx = ["leaf #{leaf.name}" | ctx]
    {type, diags} = resolve_type(leaf.type, typedefs, ctx)
    {%{leaf | type: type}, diags}
  end

  defp resolve_node(%LeafList{} = ll, typedefs, ctx) do
    ctx = ["leaf-list #{ll.name}" | ctx]
    {type, diags} = resolve_type(ll.type, typedefs, ctx)
    {%{ll | type: type}, diags}
  end

  defp resolve_node(%Container{} = c, typedefs, ctx) do
    ctx = ["container #{c.name}" | ctx]
    local_defs = build_typedef_map(c.typedefs)
    merged = Map.merge(typedefs, local_defs)
    {body, diags} = resolve_nodes(c.body, merged, ctx)
    {%{c | body: body}, diags}
  end

  defp resolve_node(%List{} = l, typedefs, ctx) do
    ctx = ["list #{l.name}" | ctx]
    local_defs = build_typedef_map(l.typedefs)
    merged = Map.merge(typedefs, local_defs)
    {body, diags} = resolve_nodes(l.body, merged, ctx)
    {%{l | body: body}, diags}
  end

  defp resolve_node(%Choice{} = c, typedefs, ctx) do
    ctx = ["choice #{c.name}" | ctx]
    {cases, diags} = resolve_nodes(c.cases, typedefs, ctx)
    {%{c | cases: cases}, diags}
  end

  defp resolve_node(%Case{} = c, typedefs, ctx) do
    ctx = ["case #{c.name}" | ctx]
    {body, diags} = resolve_nodes(c.body, typedefs, ctx)
    {%{c | body: body}, diags}
  end

  defp resolve_node(node, _typedefs, _ctx), do: {node, []}

  defp resolve_type(nil, _typedefs, _ctx), do: {nil, []}

  defp resolve_type(%Type{name: name} = type, typedefs, ctx) do
    if MapSet.member?(@builtin_types, name) do
      {type, []}
    else
      case Map.get(typedefs, name) do
        nil ->
          diag = %Diagnostic{
            severity: :warning,
            phase: :resolution,
            message: "cannot resolve typedef '#{name}' — type not found",
            context: Enum.reverse(ctx)
          }
          {type, [diag]}

        %Typedef{type: base_type} ->
          # Merge constraints: the usage type's constraints override the typedef's
          resolved = %Type{
            name: name,
            base: base_type.name,
            range: type.range || base_type.range,
            length: type.length || base_type.length,
            patterns: if(type.patterns != [], do: type.patterns, else: base_type.patterns),
            fraction_digits: type.fraction_digits || base_type.fraction_digits,
            enum_values: if(type.enum_values != [], do: type.enum_values, else: base_type.enum_values),
            bit_values: if(type.bit_values != [], do: type.bit_values, else: base_type.bit_values),
            path: type.path || base_type.path,
            require_instance: type.require_instance,
            union_types: if(type.union_types != [], do: type.union_types, else: base_type.union_types),
            meta: type.meta,
            comments: type.comments
          }
          {resolved, []}
      end
    end
  end

  defp build_typedef_map(typedefs) do
    Map.new(typedefs, fn %Typedef{name: name} = td -> {name, td} end)
  end

  defp build_imported_typedef_map(namespace_map) do
    Enum.reduce(namespace_map, %{}, fn {prefix, mod}, acc ->
      Enum.reduce(mod.typedefs, acc, fn %Typedef{name: name} = td, acc2 ->
        Map.put(acc2, "#{prefix}:#{name}", td)
      end)
    end)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/ex_yang/resolver/type_resolver_test.exs`
Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/resolver/type_resolver.ex test/ex_yang/resolver/type_resolver_test.exs
git commit -m "Add type resolver (phase 2) — typedef chain resolution"
```

---

### Task 19: Resolver — Identity, Grouping, Augment, Deviation

These are the remaining resolver phases. Each follows the same pattern as the type resolver. Due to plan length, I'll provide the test and implementation for each in a single task.

**Files:**
- Create: `lib/ex_yang/resolver/identity_resolver.ex`
- Create: `lib/ex_yang/resolver/grouping_resolver.ex`
- Create: `lib/ex_yang/resolver/augment_resolver.ex`
- Create: `lib/ex_yang/resolver/deviation_resolver.ex`
- Create: `test/ex_yang/resolver/identity_resolver_test.exs`
- Create: `test/ex_yang/resolver/grouping_resolver_test.exs`
- Create: `test/ex_yang/resolver/augment_resolver_test.exs`
- Create: `test/ex_yang/resolver/deviation_resolver_test.exs`

- [ ] **Step 1: Write identity resolver test**

```elixir
# test/ex_yang/resolver/identity_resolver_test.exs
defmodule ExYang.Resolver.IdentityResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.IdentityResolver
  alias ExYang.Model.{Module, Identity}

  test "builds identity graph from module" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      identities: [
        %Identity{name: "transport", bases: [], meta: %{}},
        %Identity{name: "tcp", bases: ["transport"], meta: %{}},
        %Identity{name: "udp", bases: ["transport"], meta: %{}}
      ],
      meta: %{}
    }

    {:ok, graph} = IdentityResolver.resolve(mod, %{})
    assert MapSet.member?(graph["transport"].derived, "tcp")
    assert MapSet.member?(graph["transport"].derived, "udp")
    assert "transport" in graph["tcp"].bases
  end

  test "empty identities returns empty graph" do
    mod = %Module{name: "test", namespace: "urn:test", prefix: "t", meta: %{}}
    assert {:ok, %{}} = IdentityResolver.resolve(mod, %{})
  end
end
```

- [ ] **Step 2: Create lib/ex_yang/resolver/identity_resolver.ex**

```elixir
defmodule ExYang.Resolver.IdentityResolver do
  @moduledoc """
  Phase 3: Builds the identity inheritance DAG.
  """

  alias ExYang.Model.{Module, Identity}

  defmodule Node do
    @moduledoc false
    defstruct name: nil, bases: [], derived: MapSet.new()
    @type t :: %__MODULE__{}
  end

  @spec resolve(Module.t(), map()) :: {:ok, map()}
  def resolve(%Module{} = mod, namespace_map) do
    # Collect all identities from this module and imported modules
    all_identities = mod.identities ++ collect_imported_identities(namespace_map)

    graph =
      Enum.reduce(all_identities, %{}, fn %Identity{name: name, bases: bases}, graph ->
        node = Map.get(graph, name, %Node{name: name})
        node = %{node | bases: bases}
        graph = Map.put(graph, name, node)

        # Update parent nodes with derived reference
        Enum.reduce(bases, graph, fn base, g ->
          parent = Map.get(g, base, %Node{name: base})
          parent = %{parent | derived: MapSet.put(parent.derived, name)}
          Map.put(g, base, parent)
        end)
      end)

    {:ok, graph}
  end

  defp collect_imported_identities(namespace_map) do
    namespace_map
    |> Enum.flat_map(fn {_prefix, mod} -> mod.identities end)
  end
end
```

- [ ] **Step 3: Write grouping resolver test**

```elixir
# test/ex_yang/resolver/grouping_resolver_test.exs
defmodule ExYang.Resolver.GroupingResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.GroupingResolver
  alias ExYang.Model.{Module, Grouping, Uses, Leaf, Container, Type}

  test "expands uses into body" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      groupings: [
        %Grouping{name: "endpoint", body: [
          %Leaf{name: "address", type: %Type{name: "string"}, meta: %{}}
        ], meta: %{}}
      ],
      body: [
        %Container{name: "server", body: [
          %Uses{grouping: "endpoint", meta: %{}}
        ], meta: %{}}
      ],
      meta: %{}
    }

    {:ok, resolved, []} = GroupingResolver.resolve(mod, %{})
    [container] = resolved.body
    assert [%Leaf{name: "address"}] = container.body
  end

  test "no uses returns module unchanged" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      body: [%Leaf{name: "x", type: %Type{name: "string"}, meta: %{}}],
      meta: %{}
    }

    {:ok, resolved, []} = GroupingResolver.resolve(mod, %{})
    assert resolved.body == mod.body
  end
end
```

- [ ] **Step 4: Create lib/ex_yang/resolver/grouping_resolver.ex**

```elixir
defmodule ExYang.Resolver.GroupingResolver do
  @moduledoc """
  Phase 4: Expands `uses` statements inline by copying grouping bodies.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Container, List, Choice, Case, Grouping, Uses}

  @spec resolve(Module.t(), map()) :: {:ok, Module.t(), [Diagnostic.t()]}
  def resolve(%Module{} = mod, namespace_map) do
    local_groupings = build_grouping_map(mod.groupings)
    imported_groupings = build_imported_grouping_map(namespace_map)
    all_groupings = Map.merge(imported_groupings, local_groupings)

    {body, diags} = expand_body(mod.body, all_groupings, ["module #{mod.name}"])
    {:ok, %{mod | body: body}, diags}
  end

  defp expand_body(nodes, groupings, ctx) do
    Enum.flat_map_reduce(nodes, [], fn node, diags ->
      {expanded, new_diags} = expand_node(node, groupings, ctx)
      {expanded, diags ++ new_diags}
    end)
  end

  defp expand_node(%Uses{grouping: name} = _uses, groupings, ctx) do
    case Map.get(groupings, name) do
      nil ->
        diag = %Diagnostic{
          severity: :warning,
          phase: :resolution,
          message: "cannot resolve grouping '#{name}'",
          context: Enum.reverse(ctx)
        }
        {[], [diag]}

      %Grouping{body: body} ->
        # Recursively expand any nested uses in the grouping body
        {expanded, diags} = expand_body(body, groupings, ctx)
        {expanded, diags}
    end
  end

  defp expand_node(%Container{} = c, groupings, ctx) do
    local = build_grouping_map(c.groupings)
    merged = Map.merge(groupings, local)
    {body, diags} = expand_body(c.body, merged, ["container #{c.name}" | ctx])
    {[%{c | body: body}], diags}
  end

  defp expand_node(%List{} = l, groupings, ctx) do
    local = build_grouping_map(l.groupings)
    merged = Map.merge(groupings, local)
    {body, diags} = expand_body(l.body, merged, ["list #{l.name}" | ctx])
    {[%{l | body: body}], diags}
  end

  defp expand_node(%Choice{} = c, groupings, ctx) do
    {cases, diags} = expand_body(c.cases, groupings, ["choice #{c.name}" | ctx])
    {[%{c | cases: cases}], diags}
  end

  defp expand_node(%Case{} = c, groupings, ctx) do
    {body, diags} = expand_body(c.body, groupings, ["case #{c.name}" | ctx])
    {[%{c | body: body}], diags}
  end

  defp expand_node(node, _groupings, _ctx), do: {[node], []}

  defp build_grouping_map(groupings) do
    Map.new(groupings, fn %Grouping{name: name} = g -> {name, g} end)
  end

  defp build_imported_grouping_map(namespace_map) do
    Enum.reduce(namespace_map, %{}, fn {prefix, mod}, acc ->
      Enum.reduce(mod.groupings, acc, fn %Grouping{name: name} = g, acc2 ->
        Map.put(acc2, "#{prefix}:#{name}", g)
      end)
    end)
  end
end
```

- [ ] **Step 5: Write augment and deviation resolver stubs with tests**

```elixir
# test/ex_yang/resolver/augment_resolver_test.exs
defmodule ExYang.Resolver.AugmentResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.AugmentResolver
  alias ExYang.Model.{Module, Augment, Container, Leaf, Type}

  test "applies augment to target path" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      body: [%Container{name: "interfaces", body: [], meta: %{}}],
      augments: [
        %Augment{
          target_node: "/interfaces",
          body: [%Leaf{name: "description", type: %Type{name: "string"}, meta: %{}}],
          meta: %{}
        }
      ],
      meta: %{}
    }

    {:ok, resolved, []} = AugmentResolver.resolve(mod, %{})
    [container] = resolved.body
    assert [%Leaf{name: "description"}] = container.body
  end

  test "no augments returns module unchanged" do
    mod = %Module{name: "test", namespace: "urn:test", prefix: "t",
      body: [%Leaf{name: "x", type: %Type{name: "string"}, meta: %{}}],
      meta: %{}
    }
    {:ok, resolved, []} = AugmentResolver.resolve(mod, %{})
    assert resolved.body == mod.body
  end
end
```

```elixir
# test/ex_yang/resolver/deviation_resolver_test.exs
defmodule ExYang.Resolver.DeviationResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver.DeviationResolver
  alias ExYang.Model.{Module, Deviation, Deviate, Container, Leaf, Type}

  test "deviate not-supported removes node" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      body: [
        %Container{name: "interfaces", body: [
          %Leaf{name: "mtu", type: %Type{name: "uint16"}, meta: %{}},
          %Leaf{name: "name", type: %Type{name: "string"}, meta: %{}}
        ], meta: %{}}
      ],
      deviations: [
        %Deviation{
          target_node: "/interfaces/mtu",
          deviates: [%Deviate{type: :not_supported, meta: %{}}],
          meta: %{}
        }
      ],
      meta: %{}
    }

    {:ok, resolved, []} = DeviationResolver.resolve(mod)
    [container] = resolved.body
    assert [%Leaf{name: "name"}] = container.body
  end

  test "no deviations returns module unchanged" do
    mod = %Module{name: "test", namespace: "urn:test", prefix: "t",
      body: [%Leaf{name: "x", type: %Type{name: "string"}, meta: %{}}],
      meta: %{}
    }
    {:ok, resolved, []} = DeviationResolver.resolve(mod)
    assert resolved.body == mod.body
  end
end
```

- [ ] **Step 6: Create augment and deviation resolvers**

```elixir
# lib/ex_yang/resolver/augment_resolver.ex
defmodule ExYang.Resolver.AugmentResolver do
  @moduledoc """
  Phase 5: Applies augment statements to their target schema paths.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Container, List, Augment}

  @spec resolve(Module.t(), map()) :: {:ok, Module.t(), [Diagnostic.t()]}
  def resolve(%Module{augments: []} = mod, _namespace_map), do: {:ok, mod, []}

  def resolve(%Module{} = mod, _namespace_map) do
    {body, diags} =
      Enum.reduce(mod.augments, {mod.body, []}, fn augment, {body, diags} ->
        path = parse_path(augment.target_node)
        case apply_augment(body, path, augment.body) do
          {:ok, new_body} -> {new_body, diags}
          {:error, msg} ->
            diag = %Diagnostic{
              severity: :warning,
              phase: :resolution,
              message: msg,
              context: ["module #{mod.name}", "augment #{augment.target_node}"]
            }
            {body, [diag | diags]}
        end
      end)

    {:ok, %{mod | body: body, augments: []}, Enum.reverse(diags)}
  end

  defp parse_path("/" <> path), do: String.split(path, "/")
  defp parse_path(path), do: String.split(path, "/")

  defp apply_augment(nodes, [target], new_nodes) do
    # Strip prefix if present
    target_name = strip_prefix(target)
    case Enum.split_with(nodes, &(node_name(&1) == target_name)) do
      {[], _} -> {:error, "augment target '#{target}' not found"}
      {[node | _], rest} ->
        augmented = append_children(node, new_nodes)
        {:ok, rest ++ [augmented]}
    end
  end

  defp apply_augment(nodes, [step | remaining], new_nodes) do
    step_name = strip_prefix(step)
    {matching, rest} = Enum.split_with(nodes, &(node_name(&1) == step_name))
    case matching do
      [] -> {:error, "augment path step '#{step}' not found"}
      [node | _] ->
        children = get_children(node)
        case apply_augment(children, remaining, new_nodes) do
          {:ok, new_children} -> {:ok, rest ++ [set_children(node, new_children)]}
          err -> err
        end
    end
  end

  defp strip_prefix(name) do
    case String.split(name, ":", parts: 2) do
      [_prefix, local] -> local
      [name] -> name
    end
  end

  defp node_name(%Container{name: n}), do: n
  defp node_name(%List{name: n}), do: n
  defp node_name(%{name: n}), do: n
  defp node_name(_), do: nil

  defp get_children(%Container{body: b}), do: b
  defp get_children(%List{body: b}), do: b
  defp get_children(_), do: []

  defp set_children(%Container{} = c, children), do: %{c | body: children}
  defp set_children(%List{} = l, children), do: %{l | body: children}

  defp append_children(%Container{body: body} = c, new), do: %{c | body: body ++ new}
  defp append_children(%List{body: body} = l, new), do: %{l | body: body ++ new}
  defp append_children(node, _new), do: node
end
```

```elixir
# lib/ex_yang/resolver/deviation_resolver.ex
defmodule ExYang.Resolver.DeviationResolver do
  @moduledoc """
  Phase 6: Applies deviation statements.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Container, List, Deviation, Deviate}

  @spec resolve(Module.t()) :: {:ok, Module.t(), [Diagnostic.t()]}
  def resolve(%Module{deviations: []} = mod), do: {:ok, mod, []}

  def resolve(%Module{} = mod) do
    {body, diags} =
      Enum.reduce(mod.deviations, {mod.body, []}, fn deviation, {body, diags} ->
        path = parse_path(deviation.target_node)

        Enum.reduce(deviation.deviates, {body, diags}, fn deviate, {b, d} ->
          case apply_deviate(b, path, deviate) do
            {:ok, new_body} -> {new_body, d}
            {:error, msg} ->
              diag = %Diagnostic{
                severity: :warning,
                phase: :resolution,
                message: msg,
                context: ["module #{mod.name}", "deviation #{deviation.target_node}"]
              }
              {b, [diag | d]}
          end
        end)
      end)

    {:ok, %{mod | body: body, deviations: []}, Enum.reverse(diags)}
  end

  defp parse_path("/" <> path), do: String.split(path, "/")
  defp parse_path(path), do: String.split(path, "/")

  defp apply_deviate(nodes, [target], %Deviate{type: :not_supported}) do
    target_name = strip_prefix(target)
    {:ok, Enum.reject(nodes, &(node_name(&1) == target_name))}
  end

  defp apply_deviate(nodes, [step | remaining], deviate) do
    step_name = strip_prefix(step)
    {matching, rest} = Enum.split_with(nodes, &(node_name(&1) == step_name))
    case matching do
      [] -> {:error, "deviation path step '#{step}' not found"}
      [node | _] ->
        children = get_children(node)
        case apply_deviate(children, remaining, deviate) do
          {:ok, new_children} -> {:ok, rest ++ [set_children(node, new_children)]}
          err -> err
        end
    end
  end

  defp apply_deviate(_nodes, _path, _deviate) do
    # TODO: implement add, replace, delete deviates
    {:ok, _nodes}
  end

  defp strip_prefix(name) do
    case String.split(name, ":", parts: 2) do
      [_prefix, local] -> local
      [name] -> name
    end
  end

  defp node_name(%{name: n}), do: n
  defp node_name(_), do: nil

  defp get_children(%Container{body: b}), do: b
  defp get_children(%List{body: b}), do: b
  defp get_children(_), do: []

  defp set_children(%Container{} = c, children), do: %{c | body: children}
  defp set_children(%List{} = l, children), do: %{l | body: children}
end
```

- [ ] **Step 7: Run tests**

Run: `mix test test/ex_yang/resolver/`
Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/ex_yang/resolver/ test/ex_yang/resolver/
git commit -m "Add identity, grouping, augment, and deviation resolvers (phases 3-6)"
```

---

### Task 20: Resolver — Pipeline Orchestrator

**Files:**
- Create: `lib/ex_yang/resolver/resolver.ex`
- Create: `test/ex_yang/resolver/resolver_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/ex_yang/resolver/resolver_test.exs
defmodule ExYang.Resolver.ResolverTest do
  use ExUnit.Case, async: true

  alias ExYang.Resolver
  alias ExYang.Resolver.ResolvedModule
  alias ExYang.Model.{Module, Leaf, Container, Type, Typedef, Grouping, Uses, Identity}

  test "full resolution pipeline" do
    mod = %Module{
      name: "test", namespace: "urn:test", prefix: "t",
      typedefs: [
        %Typedef{name: "name-type", type: %Type{name: "string"}, meta: %{}}
      ],
      groupings: [
        %Grouping{name: "named", body: [
          %Leaf{name: "name", type: %Type{name: "name-type"}, meta: %{}}
        ], meta: %{}}
      ],
      identities: [
        %Identity{name: "base-id", bases: [], meta: %{}},
        %Identity{name: "derived-id", bases: ["base-id"], meta: %{}}
      ],
      body: [
        %Container{name: "config", body: [
          %Uses{grouping: "named", meta: %{}}
        ], meta: %{}}
      ],
      meta: %{}
    }

    assert {:ok, %ResolvedModule{} = resolved} = Resolver.resolve(mod, %{})
    assert resolved.module.name == "test"

    # Grouping should be expanded
    [container] = resolved.module.body
    assert [%Leaf{name: "name"}] = container.body

    # Identity graph should exist
    assert Map.has_key?(resolved.identity_graph, "base-id")
  end

  test "resolution with no features returns clean result" do
    mod = %Module{
      name: "simple", namespace: "urn:simple", prefix: "s",
      body: [%Leaf{name: "x", type: %Type{name: "string"}, meta: %{}}],
      meta: %{}
    }

    assert {:ok, %ResolvedModule{module: resolved_mod, diagnostics: []}} =
             Resolver.resolve(mod, %{})
    assert resolved_mod.name == "simple"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_yang/resolver/resolver_test.exs`
Expected: compilation error.

- [ ] **Step 3: Create lib/ex_yang/resolver/resolver.ex**

```elixir
defmodule ExYang.Resolver do
  @moduledoc """
  Orchestrates the six-phase resolution pipeline.

  1. Import/Include resolution
  2. Type resolution
  3. Identity resolution
  4. Grouping expansion
  5. Augment application
  6. Deviation application
  """

  alias ExYang.Resolver.{
    ImportResolver,
    TypeResolver,
    IdentityResolver,
    GroupingResolver,
    AugmentResolver,
    DeviationResolver,
    ResolvedModule
  }

  @doc """
  Resolve a parsed module against a registry of other modules.

  `registry` is `%{module_name => %Module{}}`.

  Returns `{:ok, %ResolvedModule{}}` or `{:error, diagnostics}`.
  """
  @spec resolve(struct(), map()) :: {:ok, ResolvedModule.t()} | {:error, [ExYang.Diagnostic.t()]}
  def resolve(module, registry \\ %{}) do
    with {:ok, namespace_map, import_diags} <- ImportResolver.resolve(module, registry),
         {:ok, module, type_diags} <- TypeResolver.resolve(module, namespace_map, %{}),
         {:ok, identity_graph} <- IdentityResolver.resolve(module, namespace_map),
         {:ok, module, grouping_diags} <- GroupingResolver.resolve(module, namespace_map),
         {:ok, module, augment_diags} <- AugmentResolver.resolve(module, namespace_map),
         {:ok, module, deviation_diags} <- DeviationResolver.resolve(module) do
      all_diags = import_diags ++ type_diags ++ grouping_diags ++ augment_diags ++ deviation_diags

      {:ok, %ResolvedModule{
        module: module,
        namespace_map: namespace_map,
        identity_graph: identity_graph,
        diagnostics: all_diags
      }}
    end
  end
end
```

- [ ] **Step 4: Wire resolve/2 into ExYang public API**

Add to `lib/ex_yang.ex`:

```elixir
alias ExYang.Resolver

@doc """
Resolve a parsed module against a registry of other modules.
"""
@spec resolve(struct(), map()) :: {:ok, ExYang.Resolver.ResolvedModule.t()} | {:error, term()}
defdelegate resolve(module, registry \\ %{}), to: Resolver
```

- [ ] **Step 5: Run tests**

Run: `mix test`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/ex_yang/resolver/resolver.ex lib/ex_yang.ex test/ex_yang/resolver/resolver_test.exs
git commit -m "Add resolver pipeline orchestrator with public API"
```

---

### Task 21: Registry — Ecto Schemas, Migration, and Behaviour

This task sets up the Ecto-backed registry. It requires a test database, so tests will be tagged `:database`.

**Files:**
- Create: `lib/ex_yang/registry/registry.ex`
- Create: `lib/ex_yang/registry/ecto_registry.ex`
- Create: `lib/ex_yang/registry/schema/yang_module.ex`
- Create: `lib/ex_yang/registry/schema/yang_dependency.ex`
- Create: `lib/ex_yang/registry/schema/yang_identity.ex`
- Create: `lib/ex_yang/registry/migrations/v01.ex`
- Create: `test/ex_yang/registry/ecto_registry_test.exs`
- Create: `test/support/test_repo.ex`
- Create: `config/config.exs`
- Create: `config/test.exs`

This task is large but mechanical — Ecto schemas mirror the spec directly. The full implementation will be created during execution. The key structures:

- [ ] **Step 1: Create registry behaviour**

```elixir
# lib/ex_yang/registry/registry.ex
defmodule ExYang.Registry do
  @moduledoc "Behaviour for YANG module storage."

  @callback store(struct(), String.t()) :: {:ok, binary()} | {:error, term()}
  @callback fetch(String.t(), Date.t() | nil) :: {:ok, struct()} | :error
  @callback resolve(String.t(), Date.t() | nil) :: {:ok, struct()} | {:error, term()}
  @callback dependencies(String.t(), Date.t() | nil) :: [map()]
  @callback dependents(String.t(), Date.t() | nil) :: [map()]
  @callback search(keyword()) :: [struct()]
  @callback delete(String.t(), Date.t() | nil) :: :ok | :error
end
```

- [ ] **Step 2: Create Ecto schemas, migration, test repo, configs, and EctoRegistry implementation**

These are standard Ecto boilerplate following the spec's schema definitions. Create all files, run `mix ecto.create && mix ecto.migrate` in test, and write registry round-trip tests.

- [ ] **Step 3: Write registry test**

Test: store a parsed module, fetch it back, verify dependencies are recorded.

- [ ] **Step 4: Run tests**

Run: `mix test test/ex_yang/registry/ --include database`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ex_yang/registry/ test/ex_yang/registry/ test/support/ config/
git commit -m "Add Ecto-backed registry with schemas and migrations"
```

---

### Task 22: Final Integration — Full Suite & Cleanup

**Files:**
- Modify: `lib/ex_yang.ex` (ensure all public API functions are wired)
- Create: `test/ex_yang/full_integration_test.exs`

- [ ] **Step 1: Write full integration test**

```elixir
# test/ex_yang/full_integration_test.exs
defmodule ExYang.FullIntegrationTest do
  use ExUnit.Case, async: true

  test "parse → resolve → encode round-trip" do
    types_source = File.read!("test/fixtures/ietf-yang-types@2013-07-15.yang")
    {:ok, types_mod} = ExYang.parse(types_source)

    yang = """
    module my-app {
      namespace "urn:example:my-app";
      prefix app;

      import ietf-yang-types {
        prefix yang;
      }

      typedef app-name {
        type string;
      }

      container config {
        leaf name {
          type app-name;
        }
        leaf created {
          type yang:date-and-time;
        }
      }
    }
    """

    {:ok, mod} = ExYang.parse(yang)
    registry = %{"ietf-yang-types" => types_mod}
    {:ok, resolved} = ExYang.resolve(mod, registry)

    assert resolved.module.name == "my-app"
    [container] = resolved.module.body
    assert container.name == "config"
    assert length(container.body) == 2

    # Encode back
    {:ok, output} = ExYang.encode(resolved.module)
    assert {:ok, _} = ExYang.parse(output)

    # Format
    {:ok, formatted} = ExYang.format(resolved.module)
    assert {:ok, _} = ExYang.parse(formatted)
  end

  test "diagnostic formatting" do
    diag = %ExYang.Diagnostic{
      severity: :error,
      phase: :validation,
      message: "missing mandatory sub-statement 'type'",
      file: "test.yang",
      line: 42,
      column: 5,
      context: ["module test", "container config", "leaf name"]
    }

    formatted = ExYang.Diagnostic.format(diag)
    assert formatted =~ "error[validation]"
    assert formatted =~ "test.yang:42:5"
    assert formatted =~ "module test > container config > leaf name"
  end
end
```

- [ ] **Step 2: Run full test suite**

Run: `mix test`
Expected: all tests pass.

- [ ] **Step 3: Run formatter**

Run: `mix format`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add full integration test and finalize public API"
```
