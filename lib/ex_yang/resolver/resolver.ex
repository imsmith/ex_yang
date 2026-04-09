defmodule ExYang.Resolver do
  @moduledoc """
  Orchestrates the full 6-phase resolver pipeline for a parsed YANG module.

  1. Import resolution — builds namespace map
  2. Type resolution — follows typedef chains
  3. Identity resolution — builds inheritance graph
  4. Grouping resolution — expands uses statements
  5. Augment resolution — applies augments to target paths
  6. Deviation resolution — applies deviations
  """

  alias ExYang.Resolver.{
    ResolvedModule,
    ImportResolver,
    TypeResolver,
    IdentityResolver,
    GroupingResolver,
    AugmentResolver,
    DeviationResolver
  }

  @spec resolve(struct(), map()) :: {:ok, ResolvedModule.t()} | {:error, [ExYang.Diagnostic.t()]}
  def resolve(module, registry \\ %{}) do
    with {:ok, namespace_map, import_diags} <- ImportResolver.resolve(module, registry),
         {:ok, identity_graph} <- IdentityResolver.resolve(module, namespace_map),
         {:ok, module, grouping_diags} <- GroupingResolver.resolve(module, namespace_map),
         {:ok, module, augment_diags} <- AugmentResolver.resolve(module, namespace_map),
         {:ok, module, deviation_diags} <- DeviationResolver.resolve(module),
         {:ok, module, type_diags} <- TypeResolver.resolve(module, namespace_map, %{}) do
      all_diags =
        import_diags ++ grouping_diags ++ augment_diags ++ deviation_diags ++ type_diags

      {:ok,
       %ResolvedModule{
         module: module,
         namespace_map: namespace_map,
         identity_graph: identity_graph,
         diagnostics: all_diags
       }}
    end
  end
end
