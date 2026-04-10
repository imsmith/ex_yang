defmodule ExYang.Transform.Builder do
  @moduledoc """
  Converts generic `{keyword, arg, sub_statements, meta}` tuples from
  the grammar into typed model structs.
  """

  alias ExYang.Model.{
    Module,
    Submodule,
    Import,
    Include,
    Revision,
    BelongsTo,
    Container,
    Leaf,
    LeafList,
    List,
    Choice,
    Case,
    AnyData,
    AnyXml,
    Grouping,
    Uses,
    Refine,
    Augment,
    Deviation,
    Deviate,
    Typedef,
    Type,
    Enum,
    Bit,
    Identity,
    Feature,
    Rpc,
    Action,
    Input,
    Output,
    Notification,
    Must,
    When,
    Range,
    Length,
    Pattern,
    ExtensionDef,
    ExtensionUse
  }

  @body_keywords [
    :container,
    :leaf,
    :"leaf-list",
    :list,
    :choice,
    :anydata,
    :anyxml,
    :uses,
    :action
  ]

  @doc """
  Build a typed struct from a generic statement tuple.

  ## Examples

      iex> tree = {:leaf, "name", [{:type, "string", [], %{line: 2}}], %{line: 1}}
      iex> {:ok, %ExYang.Model.Leaf{name: "name"}} = ExYang.Transform.Builder.build(tree)
  """
  @spec build({atom() | {atom(), atom()}, String.t() | nil, list(), map()}) ::
          {:ok, struct()} | {:error, term()}
  def build({keyword, arg, subs, meta}) do
    {:ok, do_build(keyword, arg, subs, meta)}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp take_one(subs, keyword) do
    case Elixir.Enum.find(subs, fn {kw, _, _, _} -> kw == keyword end) do
      {_, arg, _, _} -> arg
      nil -> nil
    end
  end

  defp take_all_args(subs, keyword) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} -> kw == keyword end)
    |> Elixir.Enum.map(fn {_, arg, _, _} -> arg end)
  end

  defp build_one(subs, keyword) do
    case Elixir.Enum.find(subs, fn {kw, _, _, _} -> kw == keyword end) do
      {kw, arg, sub_subs, meta} -> do_build(kw, arg, sub_subs, meta)
      nil -> nil
    end
  end

  defp build_all(subs, keyword) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} -> kw == keyword end)
    |> Elixir.Enum.map(fn {kw, arg, sub_subs, meta} -> do_build(kw, arg, sub_subs, meta) end)
  end

  defp build_body(subs) do
    subs
    |> Elixir.Enum.filter(fn {kw, _, _, _} ->
      kw in @body_keywords or is_tuple(kw)
    end)
    |> Elixir.Enum.map(fn {kw, arg, sub_subs, meta} -> do_build(kw, arg, sub_subs, meta) end)
  end

  defp take_bool(subs, keyword) do
    case take_one(subs, keyword) do
      "true" -> true
      "false" -> false
      nil -> nil
    end
  end

  defp take_int(subs, keyword) do
    case take_one(subs, keyword) do
      nil -> nil
      val -> String.to_integer(val)
    end
  end

  defp take_status(subs) do
    case take_one(subs, :status) do
      "current" -> :current
      "deprecated" -> :deprecated
      "obsolete" -> :obsolete
      nil -> nil
    end
  end

  defp take_ordered_by(subs) do
    case take_one(subs, :"ordered-by") do
      "system" -> :system
      "user" -> :user
      nil -> nil
    end
  end

  defp take_max_elements(subs) do
    case take_one(subs, :"max-elements") do
      "unbounded" -> :unbounded
      nil -> nil
      val -> String.to_integer(val)
    end
  end

  defp take_modifier(subs) do
    case take_one(subs, :modifier) do
      "invert-match" -> :invert_match
      nil -> nil
    end
  end

  defp take_deviate_type(arg) do
    case arg do
      "not-supported" -> :not_supported
      "add" -> :add
      "replace" -> :replace
      "delete" -> :delete
    end
  end

  defp comments_from(meta), do: Map.get(meta, :comments, [])

  # ---------------------------------------------------------------------------
  # Module-level
  # ---------------------------------------------------------------------------

  defp do_build(:module, name, subs, meta) do
    %Module{
      name: name,
      namespace: take_one(subs, :namespace),
      prefix: take_one(subs, :prefix),
      yang_version: take_one(subs, :"yang-version"),
      organization: take_one(subs, :organization),
      contact: take_one(subs, :contact),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      imports: build_all(subs, :import),
      includes: build_all(subs, :include),
      revisions: build_all(subs, :revision),
      body: build_body(subs),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      identities: build_all(subs, :identity),
      extensions: build_all(subs, :extension),
      rpcs: build_all(subs, :rpc),
      notifications: build_all(subs, :notification),
      augments: build_all(subs, :augment),
      deviations: build_all(subs, :deviation),
      features: build_all(subs, :feature),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:submodule, name, subs, meta) do
    %Submodule{
      name: name,
      belongs_to: build_one(subs, :"belongs-to"),
      prefix: take_one(subs, :prefix),
      yang_version: take_one(subs, :"yang-version"),
      organization: take_one(subs, :organization),
      contact: take_one(subs, :contact),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      imports: build_all(subs, :import),
      includes: build_all(subs, :include),
      revisions: build_all(subs, :revision),
      body: build_body(subs),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      identities: build_all(subs, :identity),
      extensions: build_all(subs, :extension),
      rpcs: build_all(subs, :rpc),
      notifications: build_all(subs, :notification),
      augments: build_all(subs, :augment),
      deviations: build_all(subs, :deviation),
      features: build_all(subs, :feature),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Header
  # ---------------------------------------------------------------------------

  defp do_build(:import, mod, subs, meta) do
    %Import{
      module: mod,
      prefix: take_one(subs, :prefix),
      revision_date: take_one(subs, :"revision-date"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:include, mod, subs, meta) do
    %Include{
      module: mod,
      revision_date: take_one(subs, :"revision-date"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:revision, date, subs, meta) do
    %Revision{
      date: date,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:"belongs-to", mod, subs, meta) do
    %BelongsTo{
      module: mod,
      prefix: take_one(subs, :prefix),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Data definition
  # ---------------------------------------------------------------------------

  defp do_build(:container, name, subs, meta) do
    %Container{
      name: name,
      config: take_bool(subs, :config),
      presence: take_one(subs, :presence),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:leaf, name, subs, meta) do
    %Leaf{
      name: name,
      type: build_one(subs, :type),
      default: take_one(subs, :default),
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:"leaf-list", name, subs, meta) do
    %LeafList{
      name: name,
      type: build_one(subs, :type),
      config: take_bool(subs, :config),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_max_elements(subs),
      ordered_by: take_ordered_by(subs),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:list, name, subs, meta) do
    %List{
      name: name,
      key: take_one(subs, :key),
      config: take_bool(subs, :config),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_max_elements(subs),
      ordered_by: take_ordered_by(subs),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      unique: take_all_args(subs, :unique) |> Elixir.Enum.map(&String.split/1),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:choice, name, subs, meta) do
    %Choice{
      name: name,
      default: take_one(subs, :default),
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      cases: build_all(subs, :case),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:case, name, subs, meta) do
    %Case{
      name: name,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:anydata, name, subs, meta) do
    %AnyData{
      name: name,
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:anyxml, name, subs, meta) do
    %AnyXml{
      name: name,
      config: take_bool(subs, :config),
      mandatory: take_bool(subs, :mandatory),
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Schema manipulation
  # ---------------------------------------------------------------------------

  defp do_build(:grouping, name, subs, meta) do
    %Grouping{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:uses, grouping, subs, meta) do
    %Uses{
      grouping: grouping,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      refines: build_all(subs, :refine),
      augments: build_all(subs, :augment),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:refine, target, subs, meta) do
    %Refine{
      target_node: target,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      config: take_bool(subs, :config),
      default: take_one(subs, :default),
      mandatory: take_bool(subs, :mandatory),
      presence: take_one(subs, :presence),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_max_elements(subs),
      must: build_all(subs, :must),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:augment, target, subs, meta) do
    %Augment{
      target_node: target,
      when_expr: build_one(subs, :when),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:deviation, target, subs, meta) do
    %Deviation{
      target_node: target,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      deviates: build_all(subs, :deviate),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:deviate, type_arg, subs, meta) do
    %Deviate{
      type: take_deviate_type(type_arg),
      config: take_bool(subs, :config),
      default: take_one(subs, :default),
      mandatory: take_bool(subs, :mandatory),
      type_replacement: build_one(subs, :type),
      units: take_one(subs, :units),
      min_elements: take_int(subs, :"min-elements"),
      max_elements: take_max_elements(subs),
      must: build_all(subs, :must),
      unique: take_all_args(subs, :unique) |> Elixir.Enum.map(&String.split/1),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Type system
  # ---------------------------------------------------------------------------

  defp do_build(:typedef, name, subs, meta) do
    %Typedef{
      name: name,
      type: build_one(subs, :type),
      default: take_one(subs, :default),
      status: take_status(subs),
      units: take_one(subs, :units),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:type, name, subs, meta) do
    %Type{
      name: name,
      base: take_one(subs, :base),
      range: build_one(subs, :range),
      length: build_one(subs, :length),
      fraction_digits: take_int(subs, :"fraction-digits"),
      path: take_one(subs, :path),
      require_instance: take_bool(subs, :"require-instance"),
      patterns: build_all(subs, :pattern),
      enum_values: build_all(subs, :enum),
      bit_values: build_all(subs, :bit),
      union_types: build_all(subs, :type),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:enum, name, subs, meta) do
    %Enum{
      name: name,
      value: take_int(subs, :value),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:bit, name, subs, meta) do
    %Bit{
      name: name,
      position: take_int(subs, :position),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Identity & Feature
  # ---------------------------------------------------------------------------

  defp do_build(:identity, name, subs, meta) do
    %Identity{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      bases: take_all_args(subs, :base),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:feature, name, subs, meta) do
    %Feature{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # RPC / Action / Notification
  # ---------------------------------------------------------------------------

  defp do_build(:rpc, name, subs, meta) do
    %Rpc{
      name: name,
      input: build_one(subs, :input),
      output: build_one(subs, :output),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:action, name, subs, meta) do
    %Action{
      name: name,
      input: build_one(subs, :input),
      output: build_one(subs, :output),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:input, _arg, subs, meta) do
    %Input{
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:output, _arg, subs, meta) do
    %Output{
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:notification, name, subs, meta) do
    %Notification{
      name: name,
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      must: build_all(subs, :must),
      typedefs: build_all(subs, :typedef),
      groupings: build_all(subs, :grouping),
      body: build_body(subs),
      if_features: take_all_args(subs, :"if-feature"),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Constraints
  # ---------------------------------------------------------------------------

  defp do_build(:must, xpath, subs, meta) do
    %Must{
      xpath: xpath,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:when, xpath, subs, meta) do
    %When{
      xpath: xpath,
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:range, expr, subs, meta) do
    %Range{
      expression: expr,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:length, expr, subs, meta) do
    %Length{
      expression: expr,
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  defp do_build(:pattern, value, subs, meta) do
    %Pattern{
      value: value,
      modifier: take_modifier(subs),
      error_message: take_one(subs, :"error-message"),
      error_app_tag: take_one(subs, :"error-app-tag"),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Extension definition
  # ---------------------------------------------------------------------------

  defp do_build(:extension, name, subs, meta) do
    %ExtensionDef{
      name: name,
      argument: take_one(subs, :argument),
      status: take_status(subs),
      description: take_one(subs, :description),
      reference: take_one(subs, :reference),
      meta: meta,
      comments: comments_from(meta)
    }
  end

  # ---------------------------------------------------------------------------
  # Extension use (prefixed keyword tuple)
  # ---------------------------------------------------------------------------

  defp do_build({prefix, name}, arg, subs, meta) when is_atom(prefix) and is_atom(name) do
    case ExYang.Transform.Extensions.transform({prefix, name}, arg, subs, meta) do
      {:ok, struct} ->
        struct

      :skip ->
        build_extension_use({prefix, name}, arg, subs, meta)

      {:error, _reason} ->
        build_extension_use({prefix, name}, arg, subs, meta)
    end
  end

  defp build_extension_use(keyword, arg, subs, meta) do
    sub_structs =
      subs
      |> Elixir.Enum.map(fn {kw, a, ss, m} -> do_build(kw, a, ss, m) end)
      |> Elixir.Enum.reject(&is_nil/1)

    %ExtensionUse{
      keyword: keyword,
      argument: arg,
      sub_statements: sub_structs,
      meta: meta,
      comments: comments_from(meta)
    }
  end
end
