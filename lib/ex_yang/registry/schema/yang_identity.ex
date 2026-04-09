defmodule ExYang.Registry.Schema.YangIdentity do
  @moduledoc """
  Ecto schema for YANG identities stored in the registry.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "yang_identities" do
    field :module_id, :binary_id
    field :name, :string
    field :base_names, :string
  end
end
