defmodule ExYang.Model.Identity do
  @moduledoc """
  Represents a YANG `identity` statement (RFC 7950 §7.18).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :status,
    :description,
    :reference,
    bases: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          bases: [String.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Feature do
  @moduledoc """
  Represents a YANG `feature` statement (RFC 7950 §7.20.1).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :status,
    :description,
    :reference,
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
