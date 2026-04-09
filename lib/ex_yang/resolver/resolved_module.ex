defmodule ExYang.Resolver.ResolvedModule do
  @moduledoc """
  Result of running the full resolver pipeline over a parsed YANG module.

  Holds the final (resolved) module struct, the namespace map built from
  imports, the identity inheritance graph, and any diagnostics emitted
  during resolution.
  """

  @enforce_keys [:module]
  defstruct [:module, namespace_map: %{}, identity_graph: %{}, diagnostics: []]

  @type t :: %__MODULE__{
          module: struct(),
          namespace_map: %{String.t() => struct()},
          identity_graph: %{String.t() => map()},
          diagnostics: [ExYang.Diagnostic.t()]
        }
end
