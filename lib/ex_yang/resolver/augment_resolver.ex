defmodule ExYang.Resolver.AugmentResolver do
  @moduledoc """
  Phase 5: applies augment statements to their target schema paths.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Container, List, Choice, Case}

  @doc """
  Apply augment statements to their target schema paths in the module body.
  """
  @spec resolve(ExYang.Model.Common.schema_module(), ExYang.Resolver.namespace_map()) ::
          {:ok, ExYang.Model.Common.schema_module(), [Diagnostic.t()]}
  def resolve(module, _namespace_map) do
    case module.augments do
      [] ->
        {:ok, module, []}

      augments ->
        {body, diags} =
          Enum.reduce(augments, {module.body, []}, fn aug, {body, ds} ->
            path = parse_path(aug.target_node)

            case apply_augment(body, path, aug.body) do
              {:ok, updated} ->
                {updated, ds}

              :error ->
                diag = %Diagnostic{
                  severity: :warning,
                  phase: :resolution,
                  message: "augment target \"#{aug.target_node}\" not found"
                }

                {body, [diag | ds]}
            end
          end)

        {:ok, %{module | body: body, augments: []}, Enum.reverse(diags)}
    end
  end

  defp parse_path(target_node) do
    target_node
    |> String.split("/", trim: true)
    |> Enum.map(fn segment ->
      case String.split(segment, ":", parts: 2) do
        [_prefix, name] -> name
        [name] -> name
      end
    end)
  end

  defp apply_augment(nodes, [target_name], aug_body) do
    case find_and_update(nodes, target_name, fn node ->
           append_body(node, aug_body)
         end) do
      {:ok, _} = result -> result
      :error -> :error
    end
  end

  defp apply_augment(nodes, [head | rest], aug_body) do
    find_and_update(nodes, head, fn node ->
      child_body = get_body(node)

      case apply_augment(child_body, rest, aug_body) do
        {:ok, updated} -> set_body(node, updated)
        :error -> :error
      end
    end)
  end

  defp apply_augment(_nodes, [], _aug_body), do: :error

  defp find_and_update(nodes, name, fun) do
    {updated, found} =
      Enum.map_reduce(nodes, false, fn node, found ->
        if not found and has_name?(node, name) do
          case fun.(node) do
            :error -> {node, false}
            updated_node -> {updated_node, true}
          end
        else
          {node, found}
        end
      end)

    if found, do: {:ok, updated}, else: :error
  end

  defp has_name?(node, name) do
    Map.has_key?(node, :name) and Map.get(node, :name) == name
  end

  defp get_body(%Container{body: body}), do: body
  defp get_body(%List{body: body}), do: body
  defp get_body(%Choice{cases: cases}), do: cases
  defp get_body(%Case{body: body}), do: body
  defp get_body(_), do: []

  defp set_body(%Container{} = c, body), do: %{c | body: body}
  defp set_body(%List{} = l, body), do: %{l | body: body}
  defp set_body(%Choice{} = ch, cases), do: %{ch | cases: cases}
  defp set_body(%Case{} = c, body), do: %{c | body: body}
  defp set_body(node, _body), do: node

  defp append_body(%Container{body: body} = c, new_nodes),
    do: %{c | body: body ++ new_nodes}

  defp append_body(%List{body: body} = l, new_nodes),
    do: %{l | body: body ++ new_nodes}

  defp append_body(%Case{body: body} = c, new_nodes),
    do: %{c | body: body ++ new_nodes}

  defp append_body(node, _new_nodes), do: node
end
