defmodule ExYang.IntegrationTest do
  @moduledoc """
  Integration tests against real IETF YANG modules (RFC 6021, RFC 7950, RFC 8343).

  Validates that ExYang can parse, encode, and round-trip production YANG files
  downloaded from the YangModels/yang repository.
  """
  use ExUnit.Case, async: true

  @fixtures_dir "test/fixtures"

  describe "ietf-yang-types" do
    setup do
      source = File.read!(Path.join(@fixtures_dir, "ietf-yang-types@2013-07-15.yang"))
      {:ok, mod} = ExYang.parse(source)
      %{source: source, mod: mod}
    end

    test "parses successfully", %{mod: mod} do
      assert %ExYang.Model.Module{name: "ietf-yang-types"} = mod
      assert mod.prefix == "yang"
      assert mod.namespace == "urn:ietf:params:xml:ns:yang:ietf-yang-types"
      assert length(mod.typedefs) > 10
    end

    test "contains expected typedefs", %{mod: mod} do
      names = Enum.map(mod.typedefs, & &1.name)
      assert "counter32" in names
      assert "gauge32" in names
      assert "date-and-time" in names
      assert "timestamp" in names
    end

    test "round-trip parse-encode-parse", %{source: source} do
      {:ok, mod1} = ExYang.parse(source)
      {:ok, encoded} = ExYang.encode(mod1)
      assert {:ok, %ExYang.Model.Module{name: "ietf-yang-types"} = mod2} = ExYang.parse(encoded)
      assert mod1.name == mod2.name
      assert mod1.prefix == mod2.prefix
      assert length(mod1.typedefs) == length(mod2.typedefs)
    end
  end

  describe "ietf-inet-types" do
    setup do
      source = File.read!(Path.join(@fixtures_dir, "ietf-inet-types@2013-07-15.yang"))
      {:ok, mod} = ExYang.parse(source)
      %{source: source, mod: mod}
    end

    test "parses successfully", %{mod: mod} do
      assert %ExYang.Model.Module{name: "ietf-inet-types"} = mod
      assert mod.prefix == "inet"
      assert mod.namespace == "urn:ietf:params:xml:ns:yang:ietf-inet-types"
      assert length(mod.typedefs) > 10
    end

    test "contains expected typedefs", %{mod: mod} do
      names = Enum.map(mod.typedefs, & &1.name)
      assert "ip-address" in names
      assert "ipv4-address" in names
      assert "port-number" in names
    end

    test "round-trip parse-encode-parse", %{source: source} do
      {:ok, mod1} = ExYang.parse(source)
      {:ok, encoded} = ExYang.encode(mod1)
      assert {:ok, %ExYang.Model.Module{name: "ietf-inet-types"} = mod2} = ExYang.parse(encoded)
      assert mod1.name == mod2.name
      assert mod1.prefix == mod2.prefix
      assert length(mod1.typedefs) == length(mod2.typedefs)
    end
  end

  describe "ietf-interfaces" do
    setup do
      source = File.read!(Path.join(@fixtures_dir, "ietf-interfaces@2018-02-20.yang"))
      {:ok, mod} = ExYang.parse(source)
      %{source: source, mod: mod}
    end

    test "parses successfully", %{mod: mod} do
      assert %ExYang.Model.Module{name: "ietf-interfaces"} = mod
      assert mod.prefix == "if"
      assert mod.namespace == "urn:ietf:params:xml:ns:yang:ietf-interfaces"
    end

    test "has imports", %{mod: mod} do
      import_names = Enum.map(mod.imports, & &1.module)
      assert "ietf-yang-types" in import_names
    end

    test "has container with list in body", %{mod: mod} do
      assert length(mod.body) > 0

      container =
        Enum.find(mod.body, fn
          %ExYang.Model.Container{name: "interfaces"} -> true
          _ -> false
        end)

      assert container != nil
    end

    test "round-trip parse-encode-parse", %{source: source} do
      {:ok, mod1} = ExYang.parse(source)
      {:ok, encoded} = ExYang.encode(mod1)
      assert {:ok, %ExYang.Model.Module{name: "ietf-interfaces"} = mod2} = ExYang.parse(encoded)
      assert mod1.name == mod2.name
      assert mod1.prefix == mod2.prefix
      assert length(mod1.body) == length(mod2.body)
    end
  end

  describe "parse-encode-parse invariant" do
    test "all fixtures round-trip successfully" do
      for file <- Path.wildcard(Path.join(@fixtures_dir, "*.yang")) do
        source = File.read!(file)
        {:ok, mod1} = ExYang.parse(source)
        {:ok, encoded} = ExYang.encode(mod1)
        {:ok, mod2} = ExYang.parse(encoded)
        assert mod1.name == mod2.name, "name mismatch for #{Path.basename(file)}"
        assert length(mod1.body) == length(mod2.body), "body count mismatch for #{Path.basename(file)}"
      end
    end
  end
end
