defmodule ExYang.Resolver.AugmentResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.AugmentResolver
  alias ExYang.Model.{Module, Augment, Container, Leaf, Type}

  describe "resolve/2" do
    test "applies augment to target path" do
      module = %Module{
        name: "test",
        body: [
          %Container{name: "system", body: []}
        ],
        augments: [
          %Augment{
            target_node: "/system",
            body: [%Leaf{name: "hostname", type: %Type{name: "string"}}]
          }
        ]
      }

      assert {:ok, resolved, []} = AugmentResolver.resolve(module, %{})
      [container] = resolved.body
      assert [%Leaf{name: "hostname"}] = container.body
      assert resolved.augments == []
    end

    test "no augments passes through unchanged" do
      module = %Module{
        name: "test",
        body: [%Container{name: "x", body: []}],
        augments: []
      }

      assert {:ok, resolved, []} = AugmentResolver.resolve(module, %{})
      assert resolved.body == module.body
    end

    test "missing target emits warning" do
      module = %Module{
        name: "test",
        body: [],
        augments: [
          %Augment{
            target_node: "/nonexistent",
            body: [%Leaf{name: "x", type: %Type{name: "string"}}]
          }
        ]
      }

      assert {:ok, _resolved, [diag]} = AugmentResolver.resolve(module, %{})
      assert diag.severity == :warning
      assert diag.message =~ "nonexistent"
    end
  end
end
