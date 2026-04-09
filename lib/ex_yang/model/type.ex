defmodule ExYang.Model.Typedef do
  @moduledoc """
  Represents a YANG `typedef` statement (RFC 7950 §7.3).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :type,
    :default,
    :status,
    :units,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: struct() | nil,
          default: String.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          units: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Type do
  @moduledoc """
  Represents a YANG `type` statement (RFC 7950 §7.4).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :base,
    :range,
    :length,
    :fraction_digits,
    :path,
    :require_instance,
    patterns: [],
    enum_values: [],
    bit_values: [],
    union_types: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          base: String.t() | nil,
          range: struct() | nil,
          length: struct() | nil,
          fraction_digits: non_neg_integer() | nil,
          path: String.t() | nil,
          require_instance: boolean() | nil,
          patterns: [struct()],
          enum_values: [struct()],
          bit_values: [struct()],
          union_types: [t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Enum do
  @moduledoc """
  Represents a YANG `enum` statement (RFC 7950 §9.6.4).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :value,
    :status,
    :description,
    :reference,
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          value: integer() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Bit do
  @moduledoc """
  Represents a YANG `bit` statement (RFC 7950 §9.7.4).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :position,
    :status,
    :description,
    :reference,
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          position: non_neg_integer() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
