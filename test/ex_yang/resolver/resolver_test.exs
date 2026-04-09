defmodule ExYang.ResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver
  alias ExYang.Resolver.ResolvedModule

  alias ExYang.Model.{
    Module,
    Grouping,
    Uses,
    Leaf,
    Type,
    Typedef,
    Identity,
    Container
  }

  describe "resolve/2" do
    test "full pipeline with typedefs, groupings, identities, and uses" do
      module = %Module{
        name: "test-module",
        namespace: "urn:test",
        prefix: "t",
        typedefs: [
          %Typedef{name: "name-string", type: %Type{name: "string"}}
        ],
        groupings: [
          %Grouping{
            name: "address-group",
            body: [
              %Leaf{name: "street", type: %Type{name: "string"}},
              %Leaf{name: "city", type: %Type{name: "name-string"}}
            ]
          }
        ],
        identities: [
          %Identity{name: "transport", bases: []},
          %Identity{name: "tcp", bases: ["transport"]}
        ],
        body: [
          %Container{
            name: "location",
            body: [%Uses{grouping: "address-group"}]
          }
        ]
      }

      assert {:ok, %ResolvedModule{} = result} = Resolver.resolve(module)

      # Grouping was expanded
      [container] = result.module.body
      assert length(container.body) == 2
      assert Enum.map(container.body, & &1.name) == ["street", "city"]

      # Identity graph exists
      assert Map.has_key?(result.identity_graph, "transport")
      assert MapSet.member?(result.identity_graph["transport"].derived, "tcp")

      # Type was resolved on the city leaf (name-string -> string)
      city = Enum.find(container.body, &(&1.name == "city"))
      assert city.type.base == "string"
    end

    test "empty module resolves cleanly" do
      module = %Module{name: "empty"}
      assert {:ok, %ResolvedModule{diagnostics: []}} = Resolver.resolve(module)
    end

    test "public API delegates to resolver" do
      module = %Module{name: "api-test"}
      assert {:ok, %ResolvedModule{}} = ExYang.resolve(module)
    end
  end
end
