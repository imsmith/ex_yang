defmodule ExYang.Model.Import do
  @moduledoc """
  Represents a YANG `import` statement (RFC 7950 §7.1.5).
  """

  @enforce_keys [:module]
  defstruct [
    :module,
    :prefix,
    :revision_date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          prefix: String.t() | nil,
          revision_date: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Include do
  @moduledoc """
  Represents a YANG `include` statement (RFC 7950 §7.1.6).
  """

  @enforce_keys [:module]
  defstruct [
    :module,
    :revision_date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          revision_date: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Revision do
  @moduledoc """
  Represents a YANG `revision` statement (RFC 7950 §7.1.9).
  """

  @enforce_keys [:date]
  defstruct [
    :date,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          date: String.t(),
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.BelongsTo do
  @moduledoc """
  Represents a YANG `belongs-to` statement (RFC 7950 §7.2.2).
  """

  @enforce_keys [:module]
  defstruct [
    :module,
    :prefix,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          module: String.t(),
          prefix: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
