defmodule ExYang.Model.Module do
  @moduledoc """
  Represents a YANG `module` statement (RFC 7950 §7.1).

  Implements the Access behaviour so callers can use `get_in/2`,
  `put_in/3`, and bracket syntax on module structs.
  """

  @behaviour Access

  @enforce_keys [:name]
  defstruct [
    :name,
    :namespace,
    :prefix,
    :yang_version,
    :organization,
    :contact,
    :description,
    :reference,
    imports: [],
    includes: [],
    revisions: [],
    body: [],
    typedefs: [],
    groupings: [],
    identities: [],
    extensions: [],
    rpcs: [],
    notifications: [],
    augments: [],
    deviations: [],
    features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          namespace: String.t() | nil,
          prefix: String.t() | nil,
          yang_version: String.t() | nil,
          organization: String.t() | nil,
          contact: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          imports: [ExYang.Model.Import.t()],
          includes: [ExYang.Model.Include.t()],
          revisions: [ExYang.Model.Revision.t()],
          body: [struct()],
          typedefs: [struct()],
          groupings: [struct()],
          identities: [struct()],
          extensions: [struct()],
          rpcs: [struct()],
          notifications: [struct()],
          augments: [struct()],
          deviations: [struct()],
          features: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }

  @impl Access
  def fetch(struct, key) do
    Map.fetch(struct, key)
  end

  @impl Access
  def get_and_update(struct, key, fun) do
    current = Map.get(struct, key)

    case fun.(current) do
      {get, update} -> {get, Map.put(struct, key, update)}
      :pop -> pop(struct, key)
    end
  end

  @impl Access
  def pop(struct, key) do
    default = Map.get(%__MODULE__{name: struct.name}, key)
    {Map.get(struct, key), Map.put(struct, key, default)}
  end
end

defmodule ExYang.Model.Submodule do
  @moduledoc """
  Represents a YANG `submodule` statement (RFC 7950 §7.2).

  Same shape as `ExYang.Model.Module` but carries `belongs_to`
  instead of `namespace`.
  """

  @behaviour Access

  @enforce_keys [:name]
  defstruct [
    :name,
    :belongs_to,
    :prefix,
    :yang_version,
    :organization,
    :contact,
    :description,
    :reference,
    imports: [],
    includes: [],
    revisions: [],
    body: [],
    typedefs: [],
    groupings: [],
    identities: [],
    extensions: [],
    rpcs: [],
    notifications: [],
    augments: [],
    deviations: [],
    features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          belongs_to: ExYang.Model.BelongsTo.t() | nil,
          prefix: String.t() | nil,
          yang_version: String.t() | nil,
          organization: String.t() | nil,
          contact: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          imports: [ExYang.Model.Import.t()],
          includes: [ExYang.Model.Include.t()],
          revisions: [ExYang.Model.Revision.t()],
          body: [struct()],
          typedefs: [struct()],
          groupings: [struct()],
          identities: [struct()],
          extensions: [struct()],
          rpcs: [struct()],
          notifications: [struct()],
          augments: [struct()],
          deviations: [struct()],
          features: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }

  @impl Access
  def fetch(struct, key), do: Map.fetch(struct, key)

  @impl Access
  def get_and_update(struct, key, fun) do
    current = Map.get(struct, key)

    case fun.(current) do
      {get, update} -> {get, Map.put(struct, key, update)}
      :pop -> pop(struct, key)
    end
  end

  @impl Access
  def pop(struct, key) do
    default = Map.get(%__MODULE__{name: struct.name}, key)
    {Map.get(struct, key), Map.put(struct, key, default)}
  end
end
