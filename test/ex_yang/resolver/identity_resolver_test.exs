defmodule ExYang.Resolver.IdentityResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.IdentityResolver
  alias ExYang.Model.{Module, Identity}

  describe "resolve/2" do
    test "builds graph with bases and derived" do
      module = %Module{
        name: "test",
        identities: [
          %Identity{name: "transport", bases: []},
          %Identity{name: "tcp", bases: ["transport"]},
          %Identity{name: "udp", bases: ["transport"]}
        ]
      }

      assert {:ok, graph} = IdentityResolver.resolve(module, %{})
      assert graph["transport"].derived == MapSet.new(["tcp", "udp"])
      assert graph["tcp"].bases == ["transport"]
      assert graph["udp"].bases == ["transport"]
    end

    test "empty identities produces empty graph" do
      module = %Module{name: "test", identities: []}
      assert {:ok, %{}} = IdentityResolver.resolve(module, %{})
    end
  end
end
