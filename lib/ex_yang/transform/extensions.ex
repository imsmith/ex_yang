defmodule ExYang.Transform.Extensions do
  @moduledoc """
  Agent-based registry for YANG extension transform handlers.

  When the builder encounters a prefixed keyword `{prefix, name}` and no
  handler is registered, it wraps the statement as `%ExtensionUse{}`.
  """

  @doc "Transform a prefixed extension keyword into a typed struct. Returns `{:ok, struct}` to replace the default wrapper, `:skip` to drop the statement, or `{:error, reason}` to fall back to `%ExtensionUse{}`."
  @callback transform({String.t(), String.t()}, String.t() | nil, list(), map()) ::
              {:ok, struct()} | :skip | {:error, String.t()}

  @agent_name __MODULE__

  @doc """
  Ensure the registry agent is running. Idempotent.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case Agent.start(fn -> %{} end, name: @agent_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc """
  Register a handler module for a `{prefix, name}` extension keyword.
  """
  @spec register({String.t(), String.t()}, module()) :: :ok
  def register({prefix, name}, handler_module) when is_binary(prefix) and is_binary(name) do
    ensure_started()
    Agent.update(@agent_name, &Map.put(&1, {prefix, name}, handler_module))
  end

  @doc """
  Unregister a handler for a `{prefix, name}` extension keyword.
  """
  @spec unregister({String.t(), String.t()}) :: :ok
  def unregister({prefix, name}) when is_binary(prefix) and is_binary(name) do
    ensure_started()
    Agent.update(@agent_name, &Map.delete(&1, {prefix, name}))
  end

  @doc """
  Transform a prefixed keyword using a registered handler, or return
  `:skip` if no handler is registered (builder will wrap as ExtensionUse).
  """
  @spec transform({String.t(), String.t()}, String.t() | nil, list(), map()) ::
          {:ok, struct()} | :skip | {:error, String.t()}
  def transform({prefix, name}, arg, subs, meta) when is_binary(prefix) and is_binary(name) do
    ensure_started()

    case Agent.get(@agent_name, &Map.get(&1, {prefix, name})) do
      nil -> :skip
      handler -> handler.transform({prefix, name}, arg, subs, meta)
    end
  end
end
