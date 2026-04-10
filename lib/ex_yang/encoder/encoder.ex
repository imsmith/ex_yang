defmodule ExYang.Encoder.Encoder do
  @moduledoc """
  Encodes YANG model structs back to YANG source text.

  Walks the struct tree and emits valid, parseable YANG output using iodata
  internally, returning a single string. Uses 2-space indentation.
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

  @doc """
  Encode a YANG model struct back to YANG source text.

  ## Examples

      iex> {:ok, mod} = ExYang.parse("module test { namespace \\"urn:test\\"; prefix t; }")
      iex> {:ok, yang} = ExYang.Encoder.Encoder.encode(mod)
      iex> yang =~ "module test"
      true
  """
  @spec encode(struct()) :: {:ok, String.t()}
  def encode(node) do
    {:ok, node |> do_encode(0) |> IO.iodata_to_binary()}
  end

  # --- Top-level ---

  defp do_encode(%Module{} = m, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("yang-version", m.yang_version, inner),
        opt_stmt("namespace", m.namespace, inner, :quoted),
        opt_stmt("prefix", m.prefix, inner),
        opt_stmt("organization", m.organization, inner, :quoted),
        opt_stmt("contact", m.contact, inner, :quoted),
        opt_stmt("description", m.description, inner, :quoted),
        opt_stmt("reference", m.reference, inner, :quoted),
        encode_list(m.imports, inner),
        encode_list(m.includes, inner),
        encode_list(m.revisions, inner),
        encode_list(m.features, inner),
        encode_list(m.identities, inner),
        encode_list(m.extensions, inner),
        encode_list(m.typedefs, inner),
        encode_list(m.groupings, inner),
        encode_list(m.body, inner),
        encode_list(m.augments, inner),
        encode_list(m.deviations, inner),
        encode_list(m.rpcs, inner),
        encode_list(m.notifications, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "module", m.name, subs)
  end

  defp do_encode(%Submodule{} = m, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("yang-version", m.yang_version, inner),
        encode_optional(m.belongs_to, inner),
        opt_stmt("prefix", m.prefix, inner),
        opt_stmt("organization", m.organization, inner, :quoted),
        opt_stmt("contact", m.contact, inner, :quoted),
        opt_stmt("description", m.description, inner, :quoted),
        opt_stmt("reference", m.reference, inner, :quoted),
        encode_list(m.imports, inner),
        encode_list(m.includes, inner),
        encode_list(m.revisions, inner),
        encode_list(m.features, inner),
        encode_list(m.identities, inner),
        encode_list(m.extensions, inner),
        encode_list(m.typedefs, inner),
        encode_list(m.groupings, inner),
        encode_list(m.body, inner),
        encode_list(m.augments, inner),
        encode_list(m.deviations, inner),
        encode_list(m.rpcs, inner),
        encode_list(m.notifications, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "submodule", m.name, subs)
  end

  # --- Header ---

  defp do_encode(%Import{} = imp, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("prefix", imp.prefix, inner),
        opt_stmt("revision-date", imp.revision_date, inner),
        opt_stmt("description", imp.description, inner, :quoted),
        opt_stmt("reference", imp.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "import", imp.module, subs)
  end

  defp do_encode(%Include{} = inc, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("revision-date", inc.revision_date, inner),
        opt_stmt("description", inc.description, inner, :quoted),
        opt_stmt("reference", inc.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "include ", inc.module, ";\n"]
      _ -> block_stmt(indent, "include", inc.module, subs)
    end
  end

  defp do_encode(%Revision{} = r, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("description", r.description, inner, :quoted),
        opt_stmt("reference", r.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "revision ", r.date, ";\n"]
      _ -> block_stmt(indent, "revision", r.date, subs)
    end
  end

  defp do_encode(%BelongsTo{} = bt, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [opt_stmt("prefix", bt.prefix, inner)]
      |> flatten_subs()

    block_stmt(indent, "belongs-to", bt.module, subs)
  end

  # --- Data Definition ---

  defp do_encode(%Container{} = c, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(c.when_expr, inner),
        encode_if_features(c.if_features, inner),
        encode_list(c.must, inner),
        opt_stmt("presence", c.presence, inner, :quoted),
        opt_bool("config", c.config, inner),
        opt_status(c.status, inner),
        opt_stmt("description", c.description, inner, :quoted),
        opt_stmt("reference", c.reference, inner, :quoted),
        encode_list(c.typedefs, inner),
        encode_list(c.groupings, inner),
        encode_list(c.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "container", c.name, subs)
  end

  defp do_encode(%Leaf{} = l, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(l.when_expr, inner),
        encode_if_features(l.if_features, inner),
        encode_list(l.must, inner),
        encode_optional(l.type, inner),
        opt_stmt("units", l.units, inner, :quoted),
        opt_stmt("default", l.default, inner, :quoted),
        opt_bool("config", l.config, inner),
        opt_bool("mandatory", l.mandatory, inner),
        opt_status(l.status, inner),
        opt_stmt("description", l.description, inner, :quoted),
        opt_stmt("reference", l.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "leaf", l.name, subs)
  end

  defp do_encode(%LeafList{} = l, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(l.when_expr, inner),
        encode_if_features(l.if_features, inner),
        encode_list(l.must, inner),
        encode_optional(l.type, inner),
        opt_stmt("units", l.units, inner, :quoted),
        opt_bool("config", l.config, inner),
        opt_int("min-elements", l.min_elements, inner),
        opt_max_elements(l.max_elements, inner),
        opt_ordered_by(l.ordered_by, inner),
        opt_status(l.status, inner),
        opt_stmt("description", l.description, inner, :quoted),
        opt_stmt("reference", l.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "leaf-list", l.name, subs)
  end

  defp do_encode(%List{} = l, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(l.when_expr, inner),
        encode_if_features(l.if_features, inner),
        encode_list(l.must, inner),
        opt_stmt("key", l.key, inner, :quoted),
        encode_unique(l.unique, inner),
        opt_bool("config", l.config, inner),
        opt_int("min-elements", l.min_elements, inner),
        opt_max_elements(l.max_elements, inner),
        opt_ordered_by(l.ordered_by, inner),
        opt_status(l.status, inner),
        opt_stmt("description", l.description, inner, :quoted),
        opt_stmt("reference", l.reference, inner, :quoted),
        encode_list(l.typedefs, inner),
        encode_list(l.groupings, inner),
        encode_list(l.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "list", l.name, subs)
  end

  defp do_encode(%Choice{} = c, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(c.when_expr, inner),
        encode_if_features(c.if_features, inner),
        encode_list(c.must, inner),
        opt_stmt("default", c.default, inner, :quoted),
        opt_bool("config", c.config, inner),
        opt_bool("mandatory", c.mandatory, inner),
        opt_status(c.status, inner),
        opt_stmt("description", c.description, inner, :quoted),
        opt_stmt("reference", c.reference, inner, :quoted),
        encode_list(c.cases, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "choice", c.name, subs)
  end

  defp do_encode(%Case{} = c, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(c.when_expr, inner),
        encode_if_features(c.if_features, inner),
        opt_status(c.status, inner),
        opt_stmt("description", c.description, inner, :quoted),
        opt_stmt("reference", c.reference, inner, :quoted),
        encode_list(c.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "case", c.name, subs)
  end

  defp do_encode(%AnyData{} = a, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(a.when_expr, inner),
        encode_if_features(a.if_features, inner),
        encode_list(a.must, inner),
        opt_bool("config", a.config, inner),
        opt_bool("mandatory", a.mandatory, inner),
        opt_status(a.status, inner),
        opt_stmt("description", a.description, inner, :quoted),
        opt_stmt("reference", a.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "anydata", a.name, subs)
  end

  defp do_encode(%AnyXml{} = a, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(a.when_expr, inner),
        encode_if_features(a.if_features, inner),
        encode_list(a.must, inner),
        opt_bool("config", a.config, inner),
        opt_bool("mandatory", a.mandatory, inner),
        opt_status(a.status, inner),
        opt_stmt("description", a.description, inner, :quoted),
        opt_stmt("reference", a.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "anyxml", a.name, subs)
  end

  # --- Schema ---

  defp do_encode(%Grouping{} = g, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_status(g.status, inner),
        opt_stmt("description", g.description, inner, :quoted),
        opt_stmt("reference", g.reference, inner, :quoted),
        encode_list(g.typedefs, inner),
        encode_list(g.groupings, inner),
        encode_list(g.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "grouping", g.name, subs)
  end

  defp do_encode(%Uses{} = u, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(u.when_expr, inner),
        encode_if_features(u.if_features, inner),
        opt_status(u.status, inner),
        opt_stmt("description", u.description, inner, :quoted),
        opt_stmt("reference", u.reference, inner, :quoted),
        encode_list(u.refines, inner),
        encode_list(u.augments, inner)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "uses ", u.grouping, ";\n"]
      _ -> block_stmt(indent, "uses", u.grouping, subs)
    end
  end

  defp do_encode(%Refine{} = r, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_list(r.must, inner),
        opt_stmt("description", r.description, inner, :quoted),
        opt_stmt("reference", r.reference, inner, :quoted),
        opt_bool("config", r.config, inner),
        opt_stmt("default", r.default, inner, :quoted),
        opt_bool("mandatory", r.mandatory, inner),
        opt_stmt("presence", r.presence, inner, :quoted),
        opt_int("min-elements", r.min_elements, inner),
        opt_max_elements(r.max_elements, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "refine", quote_arg(r.target_node), subs)
  end

  defp do_encode(%Augment{} = a, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_when(a.when_expr, inner),
        encode_if_features(a.if_features, inner),
        opt_status(a.status, inner),
        opt_stmt("description", a.description, inner, :quoted),
        opt_stmt("reference", a.reference, inner, :quoted),
        encode_list(a.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "augment", quote_arg(a.target_node), subs)
  end

  defp do_encode(%Deviation{} = d, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("description", d.description, inner, :quoted),
        opt_stmt("reference", d.reference, inner, :quoted),
        encode_list(d.deviates, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "deviation", quote_arg(d.target_node), subs)
  end

  defp do_encode(%Deviate{} = d, depth) do
    indent = indent(depth)
    inner = depth + 1
    type_str = deviate_type(d.type)

    subs =
      [
        opt_bool("config", d.config, inner),
        opt_stmt("default", d.default, inner, :quoted),
        opt_bool("mandatory", d.mandatory, inner),
        encode_optional(d.type_replacement, inner),
        opt_stmt("units", d.units, inner, :quoted),
        opt_int("min-elements", d.min_elements, inner),
        opt_max_elements(d.max_elements, inner),
        encode_list(d.must, inner),
        encode_unique(d.unique, inner)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "deviate ", type_str, ";\n"]
      _ -> block_stmt(indent, "deviate", type_str, subs)
    end
  end

  # --- Type System ---

  defp do_encode(%Typedef{} = t, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_optional(t.type, inner),
        opt_stmt("units", t.units, inner, :quoted),
        opt_stmt("default", t.default, inner, :quoted),
        opt_status(t.status, inner),
        opt_stmt("description", t.description, inner, :quoted),
        opt_stmt("reference", t.reference, inner, :quoted)
      ]
      |> flatten_subs()

    block_stmt(indent, "typedef", t.name, subs)
  end

  defp do_encode(%Type{} = t, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("base", t.base, inner),
        encode_optional(t.range, inner),
        encode_optional(t.length, inner),
        encode_list(t.patterns, inner),
        opt_int("fraction-digits", t.fraction_digits, inner),
        opt_stmt("path", t.path, inner, :quoted),
        opt_bool("require-instance", t.require_instance, inner),
        encode_list(t.enum_values, inner),
        encode_list(t.bit_values, inner),
        encode_list(t.union_types, inner)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "type ", t.name, ";\n"]
      _ -> block_stmt(indent, "type", t.name, subs)
    end
  end

  defp do_encode(%ExYang.Model.Enum{} = e, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(e.if_features, inner),
        opt_int("value", e.value, inner),
        opt_status(e.status, inner),
        opt_stmt("description", e.description, inner, :quoted),
        opt_stmt("reference", e.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "enum ", quote_arg(e.name), ";\n"]
      _ -> block_stmt(indent, "enum", quote_arg(e.name), subs)
    end
  end

  defp do_encode(%Bit{} = b, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(b.if_features, inner),
        opt_int("position", b.position, inner),
        opt_status(b.status, inner),
        opt_stmt("description", b.description, inner, :quoted),
        opt_stmt("reference", b.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "bit ", b.name, ";\n"]
      _ -> block_stmt(indent, "bit", b.name, subs)
    end
  end

  # --- Identity / Feature ---

  defp do_encode(%Identity{} = id, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_bases(id.bases, inner),
        encode_if_features(id.if_features, inner),
        opt_status(id.status, inner),
        opt_stmt("description", id.description, inner, :quoted),
        opt_stmt("reference", id.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "identity ", id.name, ";\n"]
      _ -> block_stmt(indent, "identity", id.name, subs)
    end
  end

  defp do_encode(%Feature{} = f, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(f.if_features, inner),
        opt_status(f.status, inner),
        opt_stmt("description", f.description, inner, :quoted),
        opt_stmt("reference", f.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "feature ", f.name, ";\n"]
      _ -> block_stmt(indent, "feature", f.name, subs)
    end
  end

  # --- RPC / Action / Input / Output / Notification ---

  defp do_encode(%Rpc{} = r, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(r.if_features, inner),
        opt_status(r.status, inner),
        opt_stmt("description", r.description, inner, :quoted),
        opt_stmt("reference", r.reference, inner, :quoted),
        encode_list(r.typedefs, inner),
        encode_list(r.groupings, inner),
        encode_optional(r.input, inner),
        encode_optional(r.output, inner)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "rpc ", r.name, ";\n"]
      _ -> block_stmt(indent, "rpc", r.name, subs)
    end
  end

  defp do_encode(%Action{} = a, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(a.if_features, inner),
        opt_status(a.status, inner),
        opt_stmt("description", a.description, inner, :quoted),
        opt_stmt("reference", a.reference, inner, :quoted),
        encode_list(a.typedefs, inner),
        encode_list(a.groupings, inner),
        encode_optional(a.input, inner),
        encode_optional(a.output, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "action", a.name, subs)
  end

  defp do_encode(%Input{} = inp, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_list(inp.must, inner),
        encode_list(inp.typedefs, inner),
        encode_list(inp.groupings, inner),
        encode_list(inp.body, inner)
      ]
      |> flatten_subs()

    [indent, "input {\n", subs, indent, "}\n"]
  end

  defp do_encode(%Output{} = out, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_list(out.must, inner),
        encode_list(out.typedefs, inner),
        encode_list(out.groupings, inner),
        encode_list(out.body, inner)
      ]
      |> flatten_subs()

    [indent, "output {\n", subs, indent, "}\n"]
  end

  defp do_encode(%Notification{} = n, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        encode_if_features(n.if_features, inner),
        encode_list(n.must, inner),
        opt_status(n.status, inner),
        opt_stmt("description", n.description, inner, :quoted),
        opt_stmt("reference", n.reference, inner, :quoted),
        encode_list(n.typedefs, inner),
        encode_list(n.groupings, inner),
        encode_list(n.body, inner)
      ]
      |> flatten_subs()

    block_stmt(indent, "notification", n.name, subs)
  end

  # --- Constraints ---

  defp do_encode(%Must{} = m, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("error-message", m.error_message, inner, :quoted),
        opt_stmt("error-app-tag", m.error_app_tag, inner, :quoted),
        opt_stmt("description", m.description, inner, :quoted),
        opt_stmt("reference", m.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "must ", quote_arg(m.xpath), ";\n"]
      _ -> block_stmt(indent, "must", quote_arg(m.xpath), subs)
    end
  end

  defp do_encode(%When{} = w, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("description", w.description, inner, :quoted),
        opt_stmt("reference", w.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "when ", quote_arg(w.xpath), ";\n"]
      _ -> block_stmt(indent, "when", quote_arg(w.xpath), subs)
    end
  end

  defp do_encode(%Range{} = r, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("error-message", r.error_message, inner, :quoted),
        opt_stmt("error-app-tag", r.error_app_tag, inner, :quoted),
        opt_stmt("description", r.description, inner, :quoted),
        opt_stmt("reference", r.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "range ", quote_arg(r.expression), ";\n"]
      _ -> block_stmt(indent, "range", quote_arg(r.expression), subs)
    end
  end

  defp do_encode(%Length{} = l, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("error-message", l.error_message, inner, :quoted),
        opt_stmt("error-app-tag", l.error_app_tag, inner, :quoted),
        opt_stmt("description", l.description, inner, :quoted),
        opt_stmt("reference", l.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "length ", quote_arg(l.expression), ";\n"]
      _ -> block_stmt(indent, "length", quote_arg(l.expression), subs)
    end
  end

  defp do_encode(%Pattern{} = p, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_modifier(p.modifier, inner),
        opt_stmt("error-message", p.error_message, inner, :quoted),
        opt_stmt("error-app-tag", p.error_app_tag, inner, :quoted),
        opt_stmt("description", p.description, inner, :quoted),
        opt_stmt("reference", p.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "pattern ", quote_arg(p.value), ";\n"]
      _ -> block_stmt(indent, "pattern", quote_arg(p.value), subs)
    end
  end

  # --- Extensions ---

  defp do_encode(%ExtensionDef{} = e, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      [
        opt_stmt("argument", e.argument, inner, :quoted),
        opt_status(e.status, inner),
        opt_stmt("description", e.description, inner, :quoted),
        opt_stmt("reference", e.reference, inner, :quoted)
      ]
      |> flatten_subs()

    case subs do
      [] -> [indent, "extension ", e.name, ";\n"]
      _ -> block_stmt(indent, "extension", e.name, subs)
    end
  end

  defp do_encode(%ExtensionUse{} = e, depth) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      Enum.map(e.sub_statements, fn sub -> encode_extension_sub(sub, inner) end)
      |> flatten_subs()

    keyword = e.keyword

    case {e.argument, subs} do
      {nil, []} ->
        [indent, keyword, ";\n"]

      {arg, []} ->
        [indent, keyword, " ", quote_arg(arg), ";\n"]

      {nil, _} ->
        [indent, keyword, " {\n", subs, indent, "}\n"]

      {arg, _} ->
        [indent, keyword, " ", quote_arg(arg), " {\n", subs, indent, "}\n"]
    end
  end

  # --- Helpers ---

  defp indent(depth), do: String.duplicate("  ", depth)

  defp escape_string(s) when is_binary(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
  end

  defp quote_arg(s) when is_binary(s), do: ["\"", escape_string(s), "\""]

  defp block_stmt(indent, keyword, arg, subs) do
    [indent, keyword, " ", arg, " {\n", subs, indent, "}\n"]
  end

  defp opt_stmt(_keyword, nil, _depth), do: []
  defp opt_stmt(_keyword, "", _depth), do: []

  defp opt_stmt(keyword, value, depth) do
    ind = indent(depth)
    [ind, keyword, " ", value, ";\n"]
  end

  defp opt_stmt(_keyword, nil, _depth, _style), do: []
  defp opt_stmt(_keyword, "", _depth, _style), do: []

  defp opt_stmt(keyword, value, depth, :quoted) do
    ind = indent(depth)
    [ind, keyword, " ", quote_arg(value), ";\n"]
  end

  defp opt_bool(_keyword, nil, _depth), do: []

  defp opt_bool(keyword, value, depth) when is_boolean(value) do
    ind = indent(depth)
    [ind, keyword, " ", to_string(value), ";\n"]
  end

  defp opt_status(nil, _depth), do: []

  defp opt_status(status, depth) do
    ind = indent(depth)
    [ind, "status ", Atom.to_string(status), ";\n"]
  end

  defp opt_int(_keyword, nil, _depth), do: []

  defp opt_int(keyword, value, depth) do
    ind = indent(depth)
    [ind, keyword, " ", Integer.to_string(value), ";\n"]
  end

  defp opt_max_elements(nil, _depth), do: []

  defp opt_max_elements(:unbounded, depth) do
    ind = indent(depth)
    [ind, "max-elements unbounded;\n"]
  end

  defp opt_max_elements(value, depth) when is_integer(value) do
    ind = indent(depth)
    [ind, "max-elements ", Integer.to_string(value), ";\n"]
  end

  defp opt_ordered_by(nil, _depth), do: []

  defp opt_ordered_by(value, depth) do
    ind = indent(depth)
    [ind, "ordered-by ", Atom.to_string(value), ";\n"]
  end

  defp opt_modifier(nil, _depth), do: []

  defp opt_modifier(:invert_match, depth) do
    ind = indent(depth)
    [ind, "modifier invert-match;\n"]
  end

  defp encode_when(nil, _depth), do: []
  defp encode_when(w, depth), do: do_encode(w, depth)

  defp encode_optional(nil, _depth), do: []
  defp encode_optional(node, depth), do: do_encode(node, depth)

  defp encode_list([], _depth), do: []
  defp encode_list(items, depth), do: Enum.map(items, &do_encode(&1, depth))

  defp encode_if_features([], _depth), do: []

  defp encode_if_features(features, depth) do
    ind = indent(depth)
    Enum.map(features, fn f -> [ind, "if-feature ", quote_arg(f), ";\n"] end)
  end

  defp encode_bases([], _depth), do: []

  defp encode_bases(bases, depth) do
    ind = indent(depth)
    Enum.map(bases, fn b -> [ind, "base ", b, ";\n"] end)
  end

  defp encode_unique([], _depth), do: []

  defp encode_unique(uniques, depth) do
    ind = indent(depth)

    Enum.map(uniques, fn cols ->
      [ind, "unique ", quote_arg(Enum.join(cols, " ")), ";\n"]
    end)
  end

  defp encode_extension_sub({keyword, arg, children}, depth) when is_list(children) do
    indent = indent(depth)
    inner = depth + 1

    subs =
      Enum.map(children, fn child -> encode_extension_sub(child, inner) end)
      |> flatten_subs()

    case {arg, subs} do
      {nil, []} -> [indent, keyword, ";\n"]
      {a, []} -> [indent, keyword, " ", quote_arg(a), ";\n"]
      {nil, _} -> [indent, keyword, " {\n", subs, indent, "}\n"]
      {a, _} -> [indent, keyword, " ", quote_arg(a), " {\n", subs, indent, "}\n"]
    end
  end

  defp encode_extension_sub({keyword, arg}, depth) do
    indent = indent(depth)

    case arg do
      nil -> [indent, keyword, ";\n"]
      a -> [indent, keyword, " ", quote_arg(a), ";\n"]
    end
  end

  defp deviate_type(:not_supported), do: "not-supported"
  defp deviate_type(:add), do: "add"
  defp deviate_type(:replace), do: "replace"
  defp deviate_type(:delete), do: "delete"

  defp flatten_subs(list) do
    list
    |> Elixir.List.flatten()
    |> case do
      [] -> []
      other -> other
    end
  end
end
