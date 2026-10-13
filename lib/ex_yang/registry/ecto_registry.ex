defmodule ExYang.Registry.EctoRegistry do
  @moduledoc """
  Ecto-backed implementation of `ExYang.Registry`.

  Stores parsed YANG modules in a relational database, tracks
  inter-module dependencies, and supports lookup by name/revision.

  The Ecto repo is passed as a parameter to every function rather
  than configured globally — this lets consuming applications use
  their own repo.
  """

  @behaviour ExYang.Registry

  alias ExYang.Model.Common

  alias ExYang.Registry.Schema.{YangModule, YangDependency, YangIdentity}
  import Ecto.Query

  # ── Behaviour callbacks ──────────────────────────────────────────

  @impl ExYang.Registry
  @spec store(Common.schema_module(), String.t()) ::
          {:ok, binary()} | {:error, Ecto.Changeset.t()}
  def store(module, source) do
    store(module, source, default_repo())
  end

  @impl ExYang.Registry
  @spec fetch(String.t(), String.t() | nil) :: {:ok, Common.schema_module()} | :error
  def fetch(name, revision) do
    fetch(name, revision, default_repo())
  end

  @impl ExYang.Registry
  @spec dependencies(String.t(), String.t() | nil) :: [ExYang.Registry.dependency()]
  def dependencies(name, revision) do
    dependencies(name, revision, default_repo())
  end

  @impl ExYang.Registry
  @spec dependents(String.t(), String.t() | nil) :: [ExYang.Registry.dependency()]
  def dependents(name, revision) do
    dependents(name, revision, default_repo())
  end

  @impl ExYang.Registry
  @spec search(keyword()) :: [Common.schema_module()]
  def search(filters) do
    search(filters, default_repo())
  end

  @impl ExYang.Registry
  @spec delete(String.t(), String.t() | nil) :: :ok | :error
  def delete(name, revision) do
    delete(name, revision, default_repo())
  end

  # ── Repo-parameterized API ───────────────────────────────────────

  @doc "Store a parsed module with its source, using the given repo."
  @spec store(Common.schema_module(), String.t(), module()) ::
          {:ok, binary()} | {:error, Ecto.Changeset.t()}
  def store(module, source, repo) do
    attrs = %{
      name: module.name,
      revision: get_latest_revision(module),
      namespace: Map.get(module, :namespace),
      yang_version: module.yang_version,
      source: source,
      parsed_ast: :erlang.term_to_binary(module),
      status: :parsed
    }

    changeset = YangModule.changeset(%YangModule{}, attrs)

    case repo.insert(changeset,
           on_conflict: :replace_all,
           conflict_target: [:name, :revision]
         ) do
      {:ok, record} ->
        store_dependencies(record, module, repo)
        store_identities(record, module, repo)
        {:ok, record.id}

      {:error, _} = err ->
        err
    end
  end

  @doc "Fetch a module by name and optional revision string, using the given repo."
  @spec fetch(String.t(), String.t() | nil, module()) :: {:ok, Common.schema_module()} | :error
  def fetch(name, revision, repo) do
    query = from_name_revision(name, revision)

    case repo.one(query) do
      nil -> :error
      record -> {:ok, :erlang.binary_to_term(record.parsed_ast, [:safe])}
    end
  end

  @doc "List dependency records for a module, using the given repo."
  @spec dependencies(String.t(), String.t() | nil, module()) :: [ExYang.Registry.dependency()]
  def dependencies(name, revision, repo) do
    with {:ok, record} <- fetch_record(name, revision, repo) do
      query =
        from(d in YangDependency,
          join: m in YangModule,
          on: d.target_module_id == m.id,
          where: d.source_module_id == ^record.id,
          select: %{name: m.name, revision: m.revision, type: d.type}
        )

      repo.all(query)
    else
      :error -> []
    end
  end

  @doc "List modules that depend on the given module, using the given repo."
  @spec dependents(String.t(), String.t() | nil, module()) :: [ExYang.Registry.dependency()]
  def dependents(name, revision, repo) do
    with {:ok, record} <- fetch_record(name, revision, repo) do
      query =
        from(d in YangDependency,
          join: m in YangModule,
          on: d.source_module_id == m.id,
          where: d.target_module_id == ^record.id,
          select: %{name: m.name, revision: m.revision, type: d.type}
        )

      repo.all(query)
    else
      :error -> []
    end
  end

  @doc "Search modules by keyword filters, using the given repo."
  @spec search(keyword(), module()) :: [Common.schema_module()]
  def search(filters, repo) do
    query =
      Enum.reduce(filters, from(m in YangModule), fn
        {:name, pattern}, q -> where(q, [m], like(m.name, ^pattern))
        {:namespace, pattern}, q -> where(q, [m], like(m.namespace, ^pattern))
        {:status, status}, q -> where(q, [m], m.status == ^status)
        _, q -> q
      end)

    repo.all(query)
    |> Enum.map(fn record -> :erlang.binary_to_term(record.parsed_ast, [:safe]) end)
  end

  @doc "Delete a module by name and optional revision, using the given repo."
  @spec delete(String.t(), String.t() | nil, module()) :: :ok | :error
  def delete(name, revision, repo) do
    query = delete_query(name, revision)

    case repo.delete_all(query) do
      {0, _} -> :error
      {_, _} -> :ok
    end
  end

  # ── Private helpers ──────────────────────────────────────────────

  defp delete_query(name, nil) do
    from(m in YangModule, where: m.name == ^name)
  end

  defp delete_query(name, revision) do
    from(m in YangModule, where: m.name == ^name and m.revision == ^revision)
  end

  defp from_name_revision(name, nil) do
    from(m in YangModule,
      where: m.name == ^name,
      order_by: [desc: m.revision],
      limit: 1
    )
  end

  defp from_name_revision(name, revision) do
    from(m in YangModule,
      where: m.name == ^name and m.revision == ^revision
    )
  end

  defp fetch_record(name, revision, repo) do
    query = from_name_revision(name, revision)

    case repo.one(query) do
      nil -> :error
      record -> {:ok, record}
    end
  end

  defp get_latest_revision(module) do
    case Map.get(module, :revisions, []) do
      [%{date: date} | _] -> date
      _ -> nil
    end
  end

  defp store_dependencies(record, module, repo) do
    imports = Map.get(module, :imports, [])

    Enum.each(imports, fn imp ->
      target_name = imp.module
      target_query = from_name_revision(target_name, nil)

      case repo.one(target_query) do
        nil ->
          :ok

        target ->
          dep = %YangDependency{
            source_module_id: record.id,
            target_module_id: target.id,
            type: :import
          }

          repo.insert(dep, on_conflict: :nothing)
      end
    end)
  end

  defp store_identities(record, module, repo) do
    identities = Map.get(module, :identities, [])

    Enum.each(identities, fn identity ->
      bases =
        case Map.get(identity, :bases, []) do
          [] -> nil
          list -> Enum.join(list, "|")
        end

      ident = %YangIdentity{
        module_id: record.id,
        name: identity.name,
        base_names: bases
      }

      repo.insert(ident, on_conflict: :nothing)
    end)
  end

  defp default_repo do
    Application.get_env(:ex_yang, :repo) ||
      raise "ExYang.Registry.EctoRegistry requires :ex_yang, :repo to be configured, or pass repo explicitly"
  end
end
