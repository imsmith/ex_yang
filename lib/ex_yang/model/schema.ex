defmodule ExYang.Model.Grouping do
  @moduledoc """
  Represents a YANG `grouping` statement (RFC 7950 §7.12).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :status,
    :description,
    :reference,
    typedefs: [],
    groupings: [],
    body: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          typedefs: [struct()],
          groupings: [struct()],
          body: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Uses do
  @moduledoc """
  Represents a YANG `uses` statement (RFC 7950 §7.13).
  """

  @enforce_keys [:grouping]
  defstruct [
    :grouping,
    :when_expr,
    :status,
    :description,
    :reference,
    if_features: [],
    refines: [],
    augments: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          grouping: String.t(),
          when_expr: struct() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          refines: [struct()],
          augments: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Refine do
  @moduledoc """
  Represents a YANG `refine` statement (RFC 7950 §7.13.2).
  """

  @enforce_keys [:target_node]
  defstruct [
    :target_node,
    :description,
    :reference,
    :config,
    :default,
    :mandatory,
    :presence,
    :min_elements,
    :max_elements,
    must: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          target_node: String.t(),
          description: String.t() | nil,
          reference: String.t() | nil,
          config: ExYang.Model.Common.config(),
          default: String.t() | nil,
          mandatory: boolean() | nil,
          presence: String.t() | nil,
          min_elements: non_neg_integer() | nil,
          max_elements: non_neg_integer() | :unbounded | nil,
          must: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Augment do
  @moduledoc """
  Represents a YANG `augment` statement (RFC 7950 §7.17).
  """

  @enforce_keys [:target_node]
  defstruct [
    :target_node,
    :when_expr,
    :status,
    :description,
    :reference,
    if_features: [],
    body: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          target_node: String.t(),
          when_expr: struct() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          body: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Deviation do
  @moduledoc """
  Represents a YANG `deviation` statement (RFC 7950 §7.20.3).
  """

  @enforce_keys [:target_node]
  defstruct [
    :target_node,
    :description,
    :reference,
    deviates: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          target_node: String.t(),
          description: String.t() | nil,
          reference: String.t() | nil,
          deviates: [struct()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Deviate do
  @moduledoc """
  Represents a YANG `deviate` statement (RFC 7950 §7.20.3.2).
  """

  @enforce_keys [:type]
  defstruct [
    :type,
    :config,
    :default,
    :mandatory,
    :type_replacement,
    :units,
    :min_elements,
    :max_elements,
    must: [],
    unique: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          type: :not_supported | :add | :replace | :delete,
          config: ExYang.Model.Common.config(),
          default: String.t() | nil,
          mandatory: boolean() | nil,
          type_replacement: struct() | nil,
          units: String.t() | nil,
          min_elements: non_neg_integer() | nil,
          max_elements: non_neg_integer() | :unbounded | nil,
          must: [struct()],
          unique: [[String.t()]],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
