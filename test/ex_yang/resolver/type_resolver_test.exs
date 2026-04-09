defmodule ExYang.Resolver.TypeResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.TypeResolver
  alias ExYang.Model.{Module, Leaf, Type, Typedef}

  describe "resolve/3" do
    test "built-in types are terminals — no base set" do
      module = %Module{
        name: "test",
        body: [%Leaf{name: "x", type: %Type{name: "string"}}]
      }

      assert {:ok, resolved, []} = TypeResolver.resolve(module, %{}, %{})
      leaf = hd(resolved.body)
      assert leaf.type.name == "string"
      assert leaf.type.base == nil
    end

    test "local typedef resolves and sets base" do
      module = %Module{
        name: "test",
        typedefs: [%Typedef{name: "my-string", type: %Type{name: "string"}}],
        body: [%Leaf{name: "x", type: %Type{name: "my-string"}}]
      }

      assert {:ok, resolved, []} = TypeResolver.resolve(module, %{}, %{})
      leaf = hd(resolved.body)
      assert leaf.type.base == "string"
    end

    test "cross-module typedef via namespace map" do
      imported = %Module{
        name: "ietf-yang-types",
        typedefs: [%Typedef{name: "counter32", type: %Type{name: "uint32"}}]
      }

      namespace_map = %{"yang" => imported}

      module = %Module{
        name: "test",
        body: [%Leaf{name: "x", type: %Type{name: "yang:counter32"}}]
      }

      assert {:ok, resolved, []} = TypeResolver.resolve(module, namespace_map, %{})
      leaf = hd(resolved.body)
      assert leaf.type.base == "uint32"
    end

    test "unresolvable typedef emits warning" do
      module = %Module{
        name: "test",
        body: [%Leaf{name: "x", type: %Type{name: "unknown-type"}}]
      }

      assert {:ok, _resolved, [diag]} = TypeResolver.resolve(module, %{}, %{})
      assert diag.severity == :warning
      assert diag.message =~ "unknown-type"
    end
  end
end
