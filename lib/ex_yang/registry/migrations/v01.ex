defmodule ExYang.Registry.Migrations.V01 do
  @moduledoc """
  Initial migration for the YANG module registry.
  """
  use Ecto.Migration

  def change do
    create table(:yang_modules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :revision, :string
      add :namespace, :string
      add :yang_version, :string
      add :source, :text
      add :parsed_ast, :binary
      add :resolved_ast, :binary
      add :status, :string, default: "parsed"
      add :diagnostics, :binary
      timestamps()
    end

    create unique_index(:yang_modules, [:name, :revision])
    create index(:yang_modules, [:name])
    create index(:yang_modules, [:namespace])

    create table(:yang_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_module_id, :binary_id, null: false
      add :target_module_id, :binary_id, null: false
      add :type, :string, null: false
      add :target_node_path, :string
    end

    create index(:yang_dependencies, [:source_module_id])
    create index(:yang_dependencies, [:target_module_id])
    create index(:yang_dependencies, [:source_module_id, :type])

    create table(:yang_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :module_id, :binary_id, null: false
      add :name, :string, null: false
      add :base_names, :string
    end

    create index(:yang_identities, [:module_id])
  end
end
