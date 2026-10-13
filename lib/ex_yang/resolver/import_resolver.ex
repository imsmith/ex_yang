defmodule ExYang.Resolver.ImportResolver do
  @moduledoc """
  Phase 1: resolves import statements against a registry of known modules,
  producing a namespace map of `%{prefix => module_struct}`.
  """

  alias ExYang.Diagnostic

  @doc """
  Resolve imports for `module` against the given `registry`.

  `registry` is `%{module_name_string => %Module{}}`.

  Returns `{:ok, namespace_map, diagnostics}` or `{:error, diagnostics}`.
  """
  @spec resolve(ExYang.Model.Common.schema_module(), ExYang.Resolver.registry()) ::
          {:ok, ExYang.Resolver.namespace_map(), [Diagnostic.t()]} | {:error, [Diagnostic.t()]}
  def resolve(module, registry) do
    {ns_map, diags} =
      Enum.reduce(module.imports, {%{}, []}, fn imp, {ns, ds} ->
        case Map.fetch(registry, imp.module) do
          {:ok, target_mod} ->
            ds = maybe_warn_revision(imp, target_mod, ds)
            {Map.put(ns, imp.prefix, target_mod), ds}

          :error ->
            diag = %Diagnostic{
              severity: :error,
              phase: :resolution,
              message: "imported module \"#{imp.module}\" not found in registry"
            }

            {ns, [diag | ds]}
        end
      end)

    diags = Enum.reverse(diags)

    if Enum.any?(diags, &(&1.severity == :error)) do
      {:error, diags}
    else
      {:ok, ns_map, diags}
    end
  end

  defp maybe_warn_revision(imp, target_mod, diags) do
    case imp.revision_date do
      nil ->
        diags

      rev_date ->
        target_revisions = Map.get(target_mod, :revisions, [])
        target_dates = Enum.map(target_revisions, & &1.date)

        if rev_date in target_dates do
          diags
        else
          diag = %Diagnostic{
            severity: :warning,
            phase: :resolution,
            message:
              "import of \"#{imp.module}\" requests revision \"#{rev_date}\" " <>
                "which does not match available revisions"
          }

          [diag | diags]
        end
    end
  end
end
