defmodule ExYang.Model.Must do
  @moduledoc """
  Represents a YANG `must` statement (RFC 7950 §7.5.3).
  """

  @enforce_keys [:xpath]
  defstruct [
    :xpath,
    :xpath_ast,
    :error_message,
    :error_app_tag,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          xpath: String.t(),
          xpath_ast: term(),
          error_message: String.t() | nil,
          error_app_tag: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.When do
  @moduledoc """
  Represents a YANG `when` statement (RFC 7950 §7.21.5).
  """

  @enforce_keys [:xpath]
  defstruct [
    :xpath,
    :xpath_ast,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          xpath: String.t(),
          xpath_ast: term(),
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Range do
  @moduledoc """
  Represents a YANG `range` statement (RFC 7950 §9.2.4).
  """

  @enforce_keys [:expression]
  defstruct [
    :expression,
    :error_message,
    :error_app_tag,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          expression: String.t(),
          error_message: String.t() | nil,
          error_app_tag: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Length do
  @moduledoc """
  Represents a YANG `length` statement (RFC 7950 §9.4.4).
  """

  @enforce_keys [:expression]
  defstruct [
    :expression,
    :error_message,
    :error_app_tag,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          expression: String.t(),
          error_message: String.t() | nil,
          error_app_tag: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end

defmodule ExYang.Model.Pattern do
  @moduledoc """
  Represents a YANG `pattern` statement (RFC 7950 §9.4.5).
  """

  @enforce_keys [:value]
  defstruct [
    :value,
    :modifier,
    :error_message,
    :error_app_tag,
    :description,
    :reference,
    meta: %{},
    comments: []
  ]

  @type t :: %__MODULE__{
          value: String.t(),
          modifier: :invert_match | nil,
          error_message: String.t() | nil,
          error_app_tag: String.t() | nil,
          description: String.t() | nil,
          reference: String.t() | nil,
          meta: ExYang.Model.Common.meta(),
          comments: [ExYang.Model.Common.comment()]
        }
end
