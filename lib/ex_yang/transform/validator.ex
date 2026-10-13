defmodule ExYang.Transform.Validator do
  @moduledoc """
  Validates typed model structs against RFC 7950 cardinality rules.

  Returns `{:ok, struct}` when valid, or `{:error, [Diagnostic.t()]}`
  when mandatory sub-statements are missing.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Module, Submodule, Leaf, LeafList, Typedef}

  @doc """
  Validate a model struct against RFC 7950 cardinality rules.

  Returns `{:ok, struct}` or `{:error, diagnostics}` where diagnostics
  is a list of `Diagnostic.t()`.

  ## Examples

      iex> leaf = %ExYang.Model.Leaf{name: "x", type: %ExYang.Model.Type{name: "string"}, meta: %{}}
      iex> {:ok, _} = ExYang.Transform.Validator.validate(leaf)

      iex> bad = %ExYang.Model.Leaf{name: "x", type: nil, meta: %{line: 1}}
      iex> {:error, [%ExYang.Diagnostic{}]} = ExYang.Transform.Validator.validate(bad)
  """
  @spec validate(node) :: {:ok, node} | {:error, [Diagnostic.t()]}
        when node: ExYang.Model.Common.model_node()
  def validate(struct) do
    errors = do_validate(struct, [])

    case errors do
      [] -> {:ok, struct}
      _ -> {:error, errors}
    end
  end

  # ---------------------------------------------------------------------------
  # Top-level dispatchers
  # ---------------------------------------------------------------------------

  defp do_validate(%Module{} = m, ctx) do
    ctx = ["module #{m.name}" | ctx]

    missing_field(m.namespace, "module", "namespace", m.meta, ctx) ++
      missing_field(m.prefix, "module", "prefix", m.meta, ctx) ++
      validate_children(m, ctx)
  end

  defp do_validate(%Submodule{} = m, ctx) do
    ctx = ["submodule #{m.name}" | ctx]

    missing_field(m.belongs_to, "submodule", "belongs-to", m.meta, ctx) ++
      validate_children(m, ctx)
  end

  defp do_validate(%Leaf{} = l, ctx) do
    ctx = ["leaf #{l.name}" | ctx]
    missing_field(l.type, "leaf", "type", l.meta, ctx)
  end

  defp do_validate(%LeafList{} = l, ctx) do
    ctx = ["leaf-list #{l.name}" | ctx]
    missing_field(l.type, "leaf-list", "type", l.meta, ctx)
  end

  defp do_validate(%Typedef{} = t, ctx) do
    ctx = ["typedef #{t.name}" | ctx]
    missing_field(t.type, "typedef", "type", t.meta, ctx)
  end

  defp do_validate(struct, ctx) do
    validate_children(struct, ctx)
  end

  # ---------------------------------------------------------------------------
  # Recursive child validation
  # ---------------------------------------------------------------------------

  defp validate_children(struct, ctx) do
    []
    |> validate_list_field(struct, :body, ctx)
    |> validate_list_field(struct, :typedefs, ctx)
    |> validate_list_field(struct, :groupings, ctx)
    |> validate_list_field(struct, :rpcs, ctx)
    |> validate_list_field(struct, :notifications, ctx)
    |> validate_list_field(struct, :augments, ctx)
    |> validate_list_field(struct, :deviations, ctx)
    |> validate_list_field(struct, :cases, ctx)
    |> validate_struct_field(struct, :input, ctx)
    |> validate_struct_field(struct, :output, ctx)
  end

  defp validate_list_field(acc, struct, field, ctx) do
    case safe_get(struct, field) do
      nil -> acc
      items -> acc ++ Elixir.Enum.flat_map(items, &do_validate(&1, ctx))
    end
  end

  defp validate_struct_field(acc, struct, field, ctx) do
    case safe_get(struct, field) do
      nil -> acc
      child when is_struct(child) -> acc ++ do_validate(child, ctx)
      _ -> acc
    end
  end

  defp safe_get(struct, field) do
    if Map.has_key?(struct, field), do: Map.get(struct, field), else: nil
  end

  # ---------------------------------------------------------------------------
  # Diagnostic helpers
  # ---------------------------------------------------------------------------

  defp missing_field(nil, stmt_type, field_name, meta, ctx) do
    [
      %Diagnostic{
        severity: :error,
        phase: :validation,
        message: "#{stmt_type} is missing required '#{field_name}' statement",
        line: Map.get(meta, :line),
        column: Map.get(meta, :column),
        context: Elixir.Enum.reverse(ctx)
      }
    ]
  end

  defp missing_field(_value, _stmt_type, _field_name, _meta, _ctx), do: []
end
