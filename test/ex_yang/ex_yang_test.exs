defmodule ExYangTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Model.{Module, Leaf, Container, Type, Typedef}

  describe "parse/1" do
    test "parses minimal.yang fixture" do
      source = File.read!("test/fixtures/minimal.yang")
      assert {:ok, %Module{} = m} = ExYang.parse(source)
      assert m.name == "minimal"
      assert m.namespace == "urn:example:minimal"
      assert m.prefix == "min"
      assert [%Leaf{name: "name", type: %Type{name: "string"}}] = m.body
    end

    test "returns error on invalid YANG" do
      assert {:error, _reason} = ExYang.parse("not valid yang at all {{{")
    end

    test "returns error when module missing namespace" do
      source = """
      module bad {
        prefix b;
      }
      """

      assert {:error, diags} = ExYang.parse(source)
      assert is_list(diags)
      assert hd(diags).message =~ "namespace"
    end

    test "parses inline YANG with typedefs and containers" do
      source = """
      module inline-test {
        namespace "urn:example:inline";
        prefix it;

        typedef percentage {
          type uint8 {
            range "0..100";
          }
        }

        container config {
          leaf threshold {
            type percentage;
            description "Threshold percentage";
          }
        }
      }
      """

      assert {:ok, %Module{} = m} = ExYang.parse(source)
      assert m.name == "inline-test"
      assert [%Typedef{name: "percentage"}] = m.typedefs
      assert [%Container{name: "config", body: [%Leaf{name: "threshold"}]}] = m.body
    end
  end

  describe "parse!/1" do
    test "returns module on valid input" do
      source = File.read!("test/fixtures/minimal.yang")
      assert %Module{name: "minimal"} = ExYang.parse!(source)
    end

    test "raises on invalid input" do
      assert_raise RuntimeError, ~r/parse error/, fn ->
        ExYang.parse!("not valid yang {{{")
      end
    end
  end
end
