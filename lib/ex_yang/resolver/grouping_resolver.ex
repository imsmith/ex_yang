defmodule ExYang.Resolver.GroupingResolver do
  @moduledoc """
  Phase 4: expands `%Uses{}` nodes inline by copying the referenced
  grouping's body.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Container, List, Choice, Case, Uses}

  @doc """
  Expand `uses` statements inline by copying the referenced grouping's body.
  """
  @spec resolve(struct(), map()) :: {:ok, struct(), [Diagnostic.t()]}
  def resolve(module, namespace_map) do
    lookup = build_grouping_lookup(module, namespace_map)
    {body, diags} = walk_body(module.body, lookup, module.groupings, [])
    {:ok, %{module | body: body}, Enum.reverse(diags)}
  end

  defp build_grouping_lookup(module, namespace_map) do
    local =
      for g <- module.groupings, into: %{} do
        {g.name, g}
      end

    imported =
      for {prefix, mod} <- namespace_map,
          g <- Map.get(mod, :groupings, []),
          into: %{} do
        {"#{prefix}:#{g.name}", g}
      end

    Map.merge(local, imported)
  end

  defp walk_body(nodes, global_lookup, local_groupings, diags) do
    local_map = for g <- local_groupings, into: %{}, do: {g.name, g}
    lookup = Map.merge(global_lookup, local_map)

    {expanded, diags} =
      Enum.flat_map_reduce(nodes, diags, fn node, acc ->
        expand_node(node, lookup, acc)
      end)

    {expanded, diags}
  end

  defp expand_node(%Uses{grouping: name}, lookup, diags) do
    case Map.fetch(lookup, name) do
      {:ok, grouping} ->
        # Recursively expand any uses within the grouping body
        {body, diags} = walk_body(grouping.body, lookup, Map.get(grouping, :groupings, []), diags)
        {body, diags}

      :error ->
        diag = %Diagnostic{
          severity: :warning,
          phase: :resolution,
          message: "grouping \"#{name}\" not found"
        }

        {[], [diag | diags]}
    end
  end

  defp expand_node(%Container{} = c, lookup, diags) do
    {body, diags} = walk_body(c.body, lookup, c.groupings, diags)
    {[%{c | body: body}], diags}
  end

  defp expand_node(%List{} = l, lookup, diags) do
    {body, diags} = walk_body(l.body, lookup, l.groupings, diags)
    {[%{l | body: body}], diags}
  end

  defp expand_node(%Choice{} = ch, lookup, diags) do
    {cases, diags} =
      Enum.map_reduce(ch.cases, diags, fn c, acc ->
        {nodes, acc} = expand_node(c, lookup, acc)
        {hd(nodes), acc}
      end)

    {[%{ch | cases: cases}], diags}
  end

  defp expand_node(%Case{} = c, lookup, diags) do
    {body, diags} = walk_body(c.body, lookup, [], diags)
    {[%{c | body: body}], diags}
  end

  defp expand_node(node, _lookup, diags), do: {[node], diags}
end
