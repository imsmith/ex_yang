defmodule ExYang.Resolver.IdentityResolver do
  @moduledoc """
  Phase 3: builds an identity inheritance graph from the module's
  identities and imported identities.
  """

  @doc """
  Build the identity graph.

  Returns `{:ok, graph}` where graph is
  `%{identity_name => %{name: n, bases: [...], derived: MapSet}}`.
  """
  @spec resolve(struct(), map()) :: {:ok, map()}
  def resolve(module, namespace_map) do
    # Collect all identities: local + imported (prefixed)
    local_ids = module.identities

    imported_ids =
      for {prefix, mod} <- namespace_map,
          id <- Map.get(mod, :identities, []) do
        %{id | name: "#{prefix}:#{id.name}"}
      end

    all_ids = local_ids ++ imported_ids

    # Build initial graph entries
    graph =
      for id <- all_ids, into: %{} do
        {id.name, %{name: id.name, bases: id.bases, derived: MapSet.new()}}
      end

    # Populate derived sets
    graph =
      Enum.reduce(all_ids, graph, fn id, g ->
        Enum.reduce(id.bases, g, fn base, g2 ->
          case Map.fetch(g2, base) do
            {:ok, entry} ->
              Map.put(g2, base, %{entry | derived: MapSet.put(entry.derived, id.name)})

            :error ->
              g2
          end
        end)
      end)

    {:ok, graph}
  end
end
