defmodule ExYang.Model.ExtensionDef do
  @moduledoc """
  Represents a YANG `extension` statement (RFC 7950 §7.19).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :argument,
    :status,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          argument: String.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.ExtensionUse do
  @moduledoc """
  Represents a use of a YANG extension (vendor or standard).
  """

  @enforce_keys [:keyword]
  defstruct [
    :keyword,
    :argument,
    sub_statements: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          keyword: String.t(),
          argument: String.t() | nil,
          sub_statements: [t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
