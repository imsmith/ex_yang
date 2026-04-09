defmodule ExYang.Resolver.DeviationResolver do
  @moduledoc """
  Phase 6: applies deviations.

  Only `not-supported` is fully implemented. `add`, `replace`, and
  `delete` pass through as no-ops with a diagnostic.
  """

  alias ExYang.Diagnostic
  alias ExYang.Model.{Container, List, Choice, Case}

  @spec resolve(struct()) :: {:ok, struct(), [Diagnostic.t()]}
  def resolve(module) do
    case module.deviations do
      [] ->
        {:ok, module, []}

      deviations ->
        {body, diags} =
          Enum.reduce(deviations, {module.body, []}, fn dev, {body, ds} ->
            Enum.reduce(dev.deviates, {body, ds}, fn deviate, {b, d} ->
              apply_deviate(b, dev.target_node, deviate, d)
            end)
          end)

        {:ok, %{module | body: body, deviations: []}, Enum.reverse(diags)}
    end
  end

  defp apply_deviate(body, target_node, %{type: :not_supported}, diags) do
    path = parse_path(target_node)

    case remove_at_path(body, path) do
      {:ok, updated} ->
        {updated, diags}

      :error ->
        diag = %Diagnostic{
          severity: :warning,
          phase: :resolution,
          message: "deviation target \"#{target_node}\" not found for not-supported"
        }

        {body, [diag | diags]}
    end
  end

  defp apply_deviate(body, target_node, %{type: deviate_type}, diags) do
    diag = %Diagnostic{
      severity: :info,
      phase: :resolution,
      message:
        "deviate #{deviate_type} for \"#{target_node}\" is a stub — not applied"
    }

    {body, [diag | diags]}
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

  defp remove_at_path(nodes, [target_name]) do
    original_len = length(nodes)

    filtered =
      Enum.reject(nodes, fn node ->
        Map.has_key?(node, :name) and Map.get(node, :name) == target_name
      end)

    if length(filtered) < original_len do
      {:ok, filtered}
    else
      :error
    end
  end

  defp remove_at_path(nodes, [head | rest]) do
    {updated, found} =
      Enum.map_reduce(nodes, false, fn node, found ->
        if not found and Map.has_key?(node, :name) and Map.get(node, :name) == head do
          child_body = get_body(node)

          case remove_at_path(child_body, rest) do
            {:ok, new_body} -> {set_body(node, new_body), true}
            :error -> {node, false}
          end
        else
          {node, found}
        end
      end)

    if found, do: {:ok, updated}, else: :error
  end

  defp remove_at_path(_nodes, []), do: :error

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
end
