defmodule ExYang.Model.Common do
  @moduledoc """
  Shared type definitions used across all YANG model structs.

  Every model struct declares a `t()` type built from these aliases, so the
  whole tree is typed end to end: a `%Module{}` body is a list of
  `data_def()`, a `%Leaf{}` type is a `Type.t()`, and so on. Elixir 1.20's
  type checker infers from struct patterns and guards; these declarations
  are the documentation and Dialyzer contract that sit alongside it.
  """

  @typedoc "Metadata map attached to every model node (at least `line`)."
  @type meta :: %{optional(atom()) => term()}

  @typedoc """
  Position of a comment relative to its owning statement, as assigned by
  `ExYang.Parser.CommentAttacher`.
  """
  @type comment_position :: :leading | :inline | :floating

  @typedoc "A comment preserved from the YANG source."
  @type comment :: %{text: String.t(), position: comment_position()}

  @typedoc "YANG status value."
  @type status :: :current | :deprecated | :obsolete

  @typedoc "YANG config value."
  @type config :: boolean() | nil

  @typedoc "Top-level schema unit produced by `ExYang.parse/1`."
  @type schema_module :: ExYang.Model.Module.t() | ExYang.Model.Submodule.t()

  @typedoc "Data definition statements that may appear in a schema node body (RFC 7950 §7.5–7.15)."
  @type data_def ::
          ExYang.Model.Container.t()
          | ExYang.Model.Leaf.t()
          | ExYang.Model.LeafList.t()
          | ExYang.Model.List.t()
          | ExYang.Model.Choice.t()
          | ExYang.Model.AnyData.t()
          | ExYang.Model.AnyXml.t()
          | ExYang.Model.Uses.t()
          | ExYang.Model.Action.t()

  @typedoc """
  Anything a `body` list may hold: a `data_def()`, an `%ExtensionUse{}`, or a
  struct produced by a handler registered with `ExYang.Transform.Extensions`.
  """
  @type body_node :: data_def() | ExYang.Model.ExtensionUse.t() | struct()

  @typedoc "Any struct in the `ExYang.Model` namespace."
  @type model_node ::
          schema_module()
          | body_node()
          | ExYang.Model.Case.t()
          | ExYang.Model.Grouping.t()
          | ExYang.Model.Typedef.t()
          | ExYang.Model.Type.t()
          | ExYang.Model.Rpc.t()
          | ExYang.Model.Notification.t()
          | ExYang.Model.Augment.t()
          | ExYang.Model.Deviation.t()
          | ExYang.Model.Identity.t()
          | ExYang.Model.Feature.t()
          | ExYang.Model.ExtensionDef.t()
end
