defmodule ExYang.Model.Common do
  @moduledoc """
  Shared type definitions used across all YANG model structs.
  """

  @typedoc "Metadata map attached to every model node."
  @type meta :: %{optional(atom()) => term()}

  @typedoc "Position of a comment relative to its owning statement."
  @type comment_position :: :before | :inline | :after

  @typedoc "A comment preserved from the YANG source."
  @type comment :: {comment_position(), String.t()}

  @typedoc "YANG status value."
  @type status :: :current | :deprecated | :obsolete

  @typedoc "YANG config value."
  @type config :: boolean() | nil
end
