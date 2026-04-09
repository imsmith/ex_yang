defmodule ExYang.Registry do
  @moduledoc """
  Behaviour for YANG module registries.

  Implementations store parsed and resolved YANG modules,
  track inter-module dependencies, and support queries.
  """

  @doc "Store a parsed YANG module with its original source text. Returns the persisted record ID on success."
  @callback store(struct(), String.t()) :: {:ok, binary()} | {:error, Ecto.Changeset.t()}

  @doc "Fetch a stored module by name and optional revision date. Returns the deserialized module struct, or `:error` if not found."
  @callback fetch(String.t(), Date.t() | nil) :: {:ok, struct()} | :error

  @doc "List modules that the given module depends on (imports, includes, etc.)."
  @callback dependencies(String.t(), Date.t() | nil) :: [map()]

  @doc "List modules that depend on the given module."
  @callback dependents(String.t(), Date.t() | nil) :: [map()]

  @doc "Search stored modules by keyword filters (e.g., `name:`, `namespace:`)."
  @callback search(keyword()) :: [struct()]

  @doc "Delete a stored module by name and optional revision. Returns `:ok` on success, `:error` if the module was not found."
  @callback delete(String.t(), Date.t() | nil) :: :ok | :error
end
