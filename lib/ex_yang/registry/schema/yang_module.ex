defmodule ExYang.Registry.Schema.YangModule do
  @moduledoc """
  Ecto schema for persisted YANG modules.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "yang_modules" do
    field :name, :string
    field :revision, :string
    field :namespace, :string
    field :yang_version, :string
    field :source, :string
    field :parsed_ast, :binary
    field :resolved_ast, :binary
    field :status, Ecto.Enum, values: [:parsed, :resolved, :error]
    field :diagnostics, :binary
    timestamps()
  end

  @required_fields ~w(name status)a
  @optional_fields ~w(revision namespace yang_version source parsed_ast resolved_ast diagnostics)a

  def changeset(module, attrs) do
    module
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:name, :revision])
  end
end
