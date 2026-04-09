defmodule ExYang.Resolver.ImportResolverTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Resolver.ImportResolver
  alias ExYang.Model.{Module, Import, Revision}

  describe "resolve/2" do
    test "successful resolution maps prefix to target module" do
      target = %Module{name: "ietf-yang-types", typedefs: []}

      module = %Module{
        name: "test-mod",
        imports: [%Import{module: "ietf-yang-types", prefix: "yang"}]
      }

      registry = %{"ietf-yang-types" => target}

      assert {:ok, ns_map, []} = ImportResolver.resolve(module, registry)
      assert ns_map["yang"] == target
    end

    test "missing import produces error diagnostic" do
      module = %Module{
        name: "test-mod",
        imports: [%Import{module: "nonexistent", prefix: "nx"}]
      }

      assert {:error, [diag]} = ImportResolver.resolve(module, %{})
      assert diag.severity == :error
      assert diag.phase == :resolution
      assert diag.message =~ "nonexistent"
    end

    test "empty imports produces empty namespace map" do
      module = %Module{name: "test-mod", imports: []}
      assert {:ok, %{}, []} = ImportResolver.resolve(module, %{})
    end

    test "revision mismatch produces warning" do
      target = %Module{
        name: "ietf-yang-types",
        revisions: [%Revision{date: "2013-07-15"}]
      }

      module = %Module{
        name: "test-mod",
        imports: [
          %Import{
            module: "ietf-yang-types",
            prefix: "yang",
            revision_date: "2010-01-01"
          }
        ]
      }

      registry = %{"ietf-yang-types" => target}

      assert {:ok, ns_map, [diag]} = ImportResolver.resolve(module, registry)
      assert Map.has_key?(ns_map, "yang")
      assert diag.severity == :warning
      assert diag.message =~ "revision"
    end
  end
end
