defmodule ExYang.Registry do
  @moduledoc """
  Behaviour for YANG module registries.

  Implementations store parsed and resolved YANG modules,
  track inter-module dependencies, and support queries.
  """

  @doc "Store a parsed YANG module with its original source text. Returns the persisted record ID on success."
  @callback store(ExYang.Model.Common.schema_module(), String.t()) ::
              {:ok, binary()} | {:error, Ecto.Changeset.t()}

  @typedoc "A dependency edge as returned by `dependencies/2` and `dependents/2`."
  @type dependency :: %{name: String.t(), revision: String.t() | nil, type: atom()}

  @doc "Fetch a stored module by name and optional revision date (`YYYY-MM-DD` string). Returns the deserialized module struct, or `:error` if not found."
  @callback fetch(String.t(), String.t() | nil) ::
              {:ok, ExYang.Model.Common.schema_module()} | :error

  @doc "List modules that the given module depends on (imports, includes, etc.)."
  @callback dependencies(String.t(), String.t() | nil) :: [dependency()]

  @doc "List modules that depend on the given module."
  @callback dependents(String.t(), String.t() | nil) :: [dependency()]

  @doc "Search stored modules by keyword filters (e.g., `name:`, `namespace:`)."
  @callback search(keyword()) :: [ExYang.Model.Common.schema_module()]

  @doc "Delete a stored module by name and optional revision. Returns `:ok` on success, `:error` if the module was not found."
  @callback delete(String.t(), String.t() | nil) :: :ok | :error
end
