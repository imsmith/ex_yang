defmodule ExYang.Resolver.DeviationResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.DeviationResolver
  alias ExYang.Model.{Module, Deviation, Deviate, Container, Leaf, Type}

  describe "resolve/1" do
    test "not-supported removes target node" do
      module = %Module{
        name: "test",
        body: [
          %Container{
            name: "system",
            body: [
              %Leaf{name: "keep", type: %Type{name: "string"}},
              %Leaf{name: "remove-me", type: %Type{name: "string"}}
            ]
          }
        ],
        deviations: [
          %Deviation{
            target_node: "/system/remove-me",
            deviates: [%Deviate{type: :not_supported}]
          }
        ]
      }

      assert {:ok, resolved, []} = DeviationResolver.resolve(module)
      [container] = resolved.body
      assert [%Leaf{name: "keep"}] = container.body
      assert resolved.deviations == []
    end

    test "no deviations passes through unchanged" do
      module = %Module{
        name: "test",
        body: [%Leaf{name: "x", type: %Type{name: "string"}}],
        deviations: []
      }

      assert {:ok, resolved, []} = DeviationResolver.resolve(module)
      assert resolved.body == module.body
    end

    test "add deviate is a stub that emits info diagnostic" do
      module = %Module{
        name: "test",
        body: [%Leaf{name: "x", type: %Type{name: "string"}}],
        deviations: [
          %Deviation{
            target_node: "/x",
            deviates: [%Deviate{type: :add}]
          }
        ]
      }

      assert {:ok, _resolved, [diag]} = DeviationResolver.resolve(module)
      assert diag.severity == :info
      assert diag.message =~ "stub"
    end
  end
end
