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
          module: ExYang.Model.Common.schema_module(),
          namespace_map: ExYang.Resolver.namespace_map(),
          identity_graph: ExYang.Resolver.IdentityResolver.graph(),
          diagnostics: [ExYang.Diagnostic.t()]
        }
end
