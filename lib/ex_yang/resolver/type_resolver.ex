defmodule ExYang.Resolver.TypeResolver do
  @moduledoc """
  Phase 2: follows typedef chains to base built-in types.
  Walks the module body recursively, resolving type references on
  Leaf and LeafList nodes.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Container, Leaf, LeafList, List, Choice, Case}

  @builtin_types MapSet.new([
                   "int8",
                   "int16",
                   "int32",
                   "int64",
                   "uint8",
                   "uint16",
                   "uint32",
                   "uint64",
                   "decimal64",
                   "string",
                   "boolean",
                   "enumeration",
                   "bits",
                   "binary",
                   "leafref",
                   "identityref",
                   "empty",
                   "union",
                   "instance-identifier"
                 ])

  @spec resolve(struct(), map(), map()) :: {:ok, struct(), [Diagnostic.t()]}
  def resolve(module, namespace_map, _opts) do
    lookup = build_typedef_lookup(module, namespace_map)
    {updated_body, diags} = walk_body(module.body, lookup, module.typedefs, [])
    {:ok, %{module | body: updated_body}, Enum.reverse(diags)}
  end

  defp build_typedef_lookup(module, namespace_map) do
    local =
      for td <- module.typedefs, into: %{} do
        {td.name, td}
      end

    imported =
      for {prefix, mod} <- namespace_map,
          td <- Map.get(mod, :typedefs, []),
          into: %{} do
        {"#{prefix}:#{td.name}", td}
      end

    Map.merge(local, imported)
  end

  defp walk_body(nodes, global_lookup, local_typedefs, diags) do
    local_map = for td <- local_typedefs, into: %{}, do: {td.name, td}
    lookup = Map.merge(global_lookup, local_map)

    Enum.map_reduce(nodes, diags, fn node, acc ->
      walk_node(node, lookup, acc)
    end)
  end

  defp walk_node(%Leaf{type: type} = leaf, lookup, diags) when not is_nil(type) do
    {resolved_type, diags} = resolve_type(type, lookup, diags)
    {%{leaf | type: resolved_type}, diags}
  end

  defp walk_node(%LeafList{type: type} = ll, lookup, diags) when not is_nil(type) do
    {resolved_type, diags} = resolve_type(type, lookup, diags)
    {%{ll | type: resolved_type}, diags}
  end

  defp walk_node(%Container{} = c, lookup, diags) do
    {body, diags} = walk_body(c.body, lookup, c.typedefs, diags)
    {%{c | body: body}, diags}
  end

  defp walk_node(%List{} = l, lookup, diags) do
    {body, diags} = walk_body(l.body, lookup, l.typedefs, diags)
    {%{l | body: body}, diags}
  end

  defp walk_node(%Choice{} = ch, lookup, diags) do
    {cases, diags} =
      Enum.map_reduce(ch.cases, diags, fn c, acc ->
        walk_node(c, lookup, acc)
      end)

    {%{ch | cases: cases}, diags}
  end

  defp walk_node(%Case{} = c, lookup, diags) do
    {body, diags} = walk_body(c.body, lookup, [], diags)
    {%{c | body: body}, diags}
  end

  defp walk_node(node, _lookup, diags), do: {node, diags}

  defp resolve_type(type, lookup, diags) do
    cond do
      MapSet.member?(@builtin_types, type.name) ->
        {type, diags}

      Map.has_key?(lookup, type.name) ->
        td = Map.fetch!(lookup, type.name)
        base_name = if td.type, do: td.type.name, else: type.name
        {%{type | base: base_name}, diags}

      true ->
        diag = %Diagnostic{
          severity: :warning,
          phase: :resolution,
          message: "type \"#{type.name}\" could not be resolved"
        }

        {type, [diag | diags]}
    end
  end
end
