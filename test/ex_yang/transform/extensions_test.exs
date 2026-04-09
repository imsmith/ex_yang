defmodule ExYang.Transform.ExtensionsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ExYang.Transform.Extensions

  defmodule TestHandler do
    @moduledoc false
    @behaviour ExYang.Transform.Extensions

    @impl true
    def transform(_keyword, arg, _subs, _meta) do
      {:ok, %{custom: true, arg: arg}}
    end
  end

  defmodule SkipHandler do
    @moduledoc false
    @behaviour ExYang.Transform.Extensions

    @impl true
    def transform(_keyword, _arg, _subs, _meta) do
      :skip
    end
  end

  setup do
    Extensions.ensure_started()
    on_exit(fn -> Extensions.unregister({:test, :ext}) end)
    :ok
  end

  describe "registry operations" do
    test "transform returns :skip when no handler registered" do
      assert :skip = Extensions.transform({:unknown, :ext}, "arg", [], %{})
    end

    test "register and transform with handler" do
      Extensions.register({:test, :ext}, TestHandler)
      assert {:ok, %{custom: true, arg: "hello"}} = Extensions.transform({:test, :ext}, "hello", [], %{})
    end

    test "unregister removes handler" do
      Extensions.register({:test, :ext}, TestHandler)
      Extensions.unregister({:test, :ext})
      assert :skip = Extensions.transform({:test, :ext}, "arg", [], %{})
    end

    test "skip handler returns :skip" do
      Extensions.register({:test, :ext}, SkipHandler)
      assert :skip = Extensions.transform({:test, :ext}, "arg", [], %{})
    end
  end
end
