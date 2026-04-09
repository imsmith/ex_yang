defmodule ExYang.Resolver.GroupingResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.GroupingResolver
  alias ExYang.Model.{Module, Grouping, Uses, Leaf, Type, Container}

  describe "resolve/2" do
    test "expands uses with grouping body" do
      module = %Module{
        name: "test",
        groupings: [
          %Grouping{
            name: "address",
            body: [
              %Leaf{name: "street", type: %Type{name: "string"}},
              %Leaf{name: "city", type: %Type{name: "string"}}
            ]
          }
        ],
        body: [%Uses{grouping: "address"}]
      }

      assert {:ok, resolved, []} = GroupingResolver.resolve(module, %{})
      assert length(resolved.body) == 2
      assert Enum.map(resolved.body, & &1.name) == ["street", "city"]
    end

    test "nested groupings expand correctly" do
      module = %Module{
        name: "test",
        groupings: [
          %Grouping{
            name: "inner",
            body: [%Leaf{name: "val", type: %Type{name: "string"}}]
          },
          %Grouping{
            name: "outer",
            body: [%Uses{grouping: "inner"}]
          }
        ],
        body: [%Uses{grouping: "outer"}]
      }

      assert {:ok, resolved, []} = GroupingResolver.resolve(module, %{})
      assert [%Leaf{name: "val"}] = resolved.body
    end

    test "no uses passes through unchanged" do
      leaf = %Leaf{name: "x", type: %Type{name: "string"}}

      module = %Module{
        name: "test",
        body: [leaf]
      }

      assert {:ok, resolved, []} = GroupingResolver.resolve(module, %{})
      assert resolved.body == [leaf]
    end

    test "uses inside container expands" do
      module = %Module{
        name: "test",
        groupings: [
          %Grouping{
            name: "addr",
            body: [%Leaf{name: "city", type: %Type{name: "string"}}]
          }
        ],
        body: [
          %Container{name: "location", body: [%Uses{grouping: "addr"}]}
        ]
      }

      assert {:ok, resolved, []} = GroupingResolver.resolve(module, %{})
      [container] = resolved.body
      assert [%Leaf{name: "city"}] = container.body
    end
  end
end
