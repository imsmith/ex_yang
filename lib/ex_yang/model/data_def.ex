defmodule ExYang.Model.Container do
  @moduledoc """
  Represents a YANG `container` statement (RFC 7950 §7.5).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :config,
    :presence,
    :when_expr,
    :status,
    :description,
    :reference,
    must: [],
    if_features: [],
    typedefs: [],
    groupings: [],
    body: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          config: ExYang.Model.Common.config(),
          presence: String.t() | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          body: [ExYang.Model.Common.body_node()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Leaf do
  @moduledoc """
  Represents a YANG `leaf` statement (RFC 7950 §7.6).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :type,
    :default,
    :config,
    :mandatory,
    :when_expr,
    :status,
    :units,
    :description,
    :reference,
    must: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: ExYang.Model.Type.t() | nil,
          default: String.t() | nil,
          config: ExYang.Model.Common.config(),
          mandatory: boolean() | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          units: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.LeafList do
  @moduledoc """
  Represents a YANG `leaf-list` statement (RFC 7950 §7.7).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :type,
    :config,
    :min_elements,
    :max_elements,
    :ordered_by,
    :when_expr,
    :status,
    :units,
    :description,
    :reference,
    must: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          type: ExYang.Model.Type.t() | nil,
          config: ExYang.Model.Common.config(),
          min_elements: non_neg_integer() | nil,
          max_elements: non_neg_integer() | :unbounded | nil,
          ordered_by: :system | :user | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          units: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.List do
  @moduledoc """
  Represents a YANG `list` statement (RFC 7950 §7.8).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :key,
    :config,
    :min_elements,
    :max_elements,
    :ordered_by,
    :when_expr,
    :status,
    :description,
    :reference,
    unique: [],
    must: [],
    if_features: [],
    typedefs: [],
    groupings: [],
    body: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          key: String.t() | nil,
          config: ExYang.Model.Common.config(),
          min_elements: non_neg_integer() | nil,
          max_elements: non_neg_integer() | :unbounded | nil,
          ordered_by: :system | :user | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          unique: [[String.t()]],
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          body: [ExYang.Model.Common.body_node()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Choice do
  @moduledoc """
  Represents a YANG `choice` statement (RFC 7950 §7.9).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :default,
    :config,
    :mandatory,
    :when_expr,
    :status,
    :description,
    :reference,
    must: [],
    if_features: [],
    cases: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          default: String.t() | nil,
          config: ExYang.Model.Common.config(),
          mandatory: boolean() | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          cases: [ExYang.Model.Case.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Case do
  @moduledoc """
  Represents a YANG `case` statement (RFC 7950 §7.9.2).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
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
          name: String.t(),
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          if_features: [String.t()],
          body: [ExYang.Model.Common.body_node()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.AnyData do
  @moduledoc """
  Represents a YANG `anydata` statement (RFC 7950 §7.10).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :config,
    :mandatory,
    :when_expr,
    :status,
    :description,
    :reference,
    must: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          config: ExYang.Model.Common.config(),
          mandatory: boolean() | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.AnyXml do
  @moduledoc """
  Represents a YANG `anyxml` statement (RFC 7950 §7.11).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :config,
    :mandatory,
    :when_expr,
    :status,
    :description,
    :reference,
    must: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          config: ExYang.Model.Common.config(),
          mandatory: boolean() | nil,
          when_expr: ExYang.Model.When.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
