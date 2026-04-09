defmodule ExYang.Registry.Schema.YangDependency do
  @moduledoc """
  Ecto schema for inter-module dependencies.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "yang_dependencies" do
    field :source_module_id, :binary_id
    field :target_module_id, :binary_id
    field :type, Ecto.Enum, values: [:import, :include, :augment, :deviation, :identity_base, :uses_grouping]
    field :target_node_path, :string
  end
end
