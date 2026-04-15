defmodule ExYang.Transform.BuilderTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest ExYang.Transform.Builder

  alias ExYang.Transform.Builder
  alias ExYang.Model.{
    Module,
    Leaf,
    Container,
    List,
    Typedef,
    Grouping,
    Uses,
    Import,
    Identity,
    Rpc,
    Input,
    Type,
    ExtensionUse
  }

  @meta %{line: 1, column: 1}

  describe "build/1" do
    test "minimal module" do
      stmt = {:module, "test", [
        {:namespace, "urn:example:test", [], @meta},
        {:prefix, "t", [], @meta}
      ], @meta}

      assert {:ok, %Module{name: "test", namespace: "urn:example:test", prefix: "t"}} =
               Builder.build(stmt)
    end

    test "leaf with type" do
      stmt = {:leaf, "hostname", [
        {:type, "string", [], @meta},
        {:description, "The hostname", [], @meta}
      ], @meta}

      assert {:ok, %Leaf{name: "hostname", type: %Type{name: "string"}, description: "The hostname"}} =
               Builder.build(stmt)
    end

    test "container with children" do
      stmt = {:container, "system", [
        {:leaf, "hostname", [
          {:type, "string", [], @meta}
        ], @meta},
        {:leaf, "domain", [
          {:type, "string", [], @meta}
        ], @meta}
      ], @meta}

      assert {:ok, %Container{name: "system", body: [%Leaf{name: "hostname"}, %Leaf{name: "domain"}]}} =
               Builder.build(stmt)
    end

    test "list with key" do
      stmt = {:list, "user", [
        {:key, "name", [], @meta},
        {:leaf, "name", [
          {:type, "string", [], @meta}
        ], @meta},
        {:leaf, "role", [
          {:type, "string", [], @meta}
        ], @meta}
      ], @meta}

      assert {:ok, %List{name: "user", key: "name", body: [%Leaf{name: "name"}, %Leaf{name: "role"}]}} =
               Builder.build(stmt)
    end

    test "typedef" do
      stmt = {:typedef, "percentage", [
        {:type, "uint8", [
          {:range, "0..100", [], @meta}
        ], @meta},
        {:description, "A percentage value", [], @meta}
      ], @meta}

      assert {:ok, %Typedef{name: "percentage", type: %Type{name: "uint8"}, description: "A percentage value"}} =
               Builder.build(stmt)
    end

    test "grouping and uses" do
      grouping_stmt = {:grouping, "address", [
        {:leaf, "street", [
          {:type, "string", [], @meta}
        ], @meta}
      ], @meta}

      assert {:ok, %Grouping{name: "address", body: [%Leaf{name: "street"}]}} =
               Builder.build(grouping_stmt)

      uses_stmt = {:uses, "address", [], @meta}

      assert {:ok, %Uses{grouping: "address"}} =
               Builder.build(uses_stmt)
    end

    test "import" do
      stmt = {:import, "ietf-inet-types", [
        {:prefix, "inet", [], @meta},
        {:"revision-date", "2013-07-15", [], @meta}
      ], @meta}

      assert {:ok, %Import{module: "ietf-inet-types", prefix: "inet", revision_date: "2013-07-15"}} =
               Builder.build(stmt)
    end

    test "identity with bases" do
      stmt = {:identity, "transport", [
        {:base, "protocol", [], @meta},
        {:base, "layer4", [], @meta},
        {:description, "A transport protocol", [], @meta}
      ], @meta}

      assert {:ok, %Identity{name: "transport", bases: ["protocol", "layer4"], description: "A transport protocol"}} =
               Builder.build(stmt)
    end

    test "rpc with input" do
      stmt = {:rpc, "restart", [
        {:description, "Restart the system", [], @meta},
        {:input, nil, [
          {:leaf, "reason", [
            {:type, "string", [], @meta}
          ], @meta}
        ], @meta}
      ], @meta}

      assert {:ok, %Rpc{name: "restart", description: "Restart the system", input: %Input{body: [%Leaf{name: "reason"}]}}} =
               Builder.build(stmt)
    end

    test "extension use (prefixed keyword)" do
      stmt = {{"tailf", "info"}, "some info", [], @meta}

      assert {:ok, %ExtensionUse{keyword: {"tailf", "info"}, argument: "some info"}} =
               Builder.build(stmt)
    end

    test "module with imports, revisions, and body" do
      stmt = {:module, "example", [
        {:namespace, "urn:example:example", [], @meta},
        {:prefix, "ex", [], @meta},
        {:"yang-version", "1.1", [], @meta},
        {:import, "ietf-inet-types", [
          {:prefix, "inet", [], @meta}
        ], @meta},
        {:revision, "2024-01-01", [
          {:description, "Initial revision", [], @meta}
        ], @meta},
        {:container, "config", [
          {:leaf, "name", [
            {:type, "string", [], @meta}
          ], @meta}
        ], @meta}
      ], @meta}

      assert {:ok, %Module{} = m} = Builder.build(stmt)
      assert m.name == "example"
      assert m.yang_version == "1.1"
      assert length(m.imports) == 1
      assert hd(m.imports).module == "ietf-inet-types"
      assert length(m.revisions) == 1
      assert hd(m.revisions).date == "2024-01-01"
      assert length(m.body) == 1
      assert %Container{name: "config"} = hd(m.body)
    end
  end
end
