defmodule ExYang.Model.Rpc do
  @moduledoc """
  Represents a YANG `rpc` statement (RFC 7950 §7.14).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :input,
    :output,
    :status,
    :description,
    :reference,
    typedefs: [],
    groupings: [],
    if_features: [],
    extensions: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          input: ExYang.Model.Input.t() | nil,
          output: ExYang.Model.Output.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          if_features: [String.t()],
          extensions: [ExYang.Model.ExtensionUse.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Action do
  @moduledoc """
  Represents a YANG `action` statement (RFC 7950 §7.15).

  Structurally identical to `ExYang.Model.Rpc`.
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :input,
    :output,
    :status,
    :description,
    :reference,
    typedefs: [],
    groupings: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          input: ExYang.Model.Input.t() | nil,
          output: ExYang.Model.Output.t() | nil,
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Input do
  @moduledoc """
  Represents a YANG `input` statement (RFC 7950 §7.14.2).
  """

  @enforce_keys []
  defstruct must: [],
            typedefs: [],
            groupings: [],
            body: [],
            meta: %{},
            comments: []

  @type t :: %__MODULE__{
          must: [ExYang.Model.Must.t()],
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          body: [ExYang.Model.Common.body_node()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Output do
  @moduledoc """
  Represents a YANG `output` statement (RFC 7950 §7.14.3).
  """

  @enforce_keys []
  defstruct must: [],
            typedefs: [],
            groupings: [],
            body: [],
            meta: %{},
            comments: []

  @type t :: %__MODULE__{
          must: [ExYang.Model.Must.t()],
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          body: [ExYang.Model.Common.body_node()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Notification do
  @moduledoc """
  Represents a YANG `notification` statement (RFC 7950 §7.16).
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :status,
    :description,
    :reference,
    must: [],
    typedefs: [],
    groupings: [],
    body: [],
    if_features: [],
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          status: ExYang.Model.Common.status() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          must: [ExYang.Model.Must.t()],
          typedefs: [ExYang.Model.Typedef.t()],
          groupings: [ExYang.Model.Grouping.t()],
          body: [ExYang.Model.Common.body_node()],
          if_features: [String.t()],
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
