defmodule ExYang.Model.RemainingTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Model.{
    Typedef,
    Type,
    Bit,
    Identity,
    Feature,
    Rpc,
    Action,
    Input,
    Output,
    Notification,
    Must,
    When,
    Range,
    Length,
    Pattern,
    ExtensionDef,
    ExtensionUse
  }

  alias ExYang.Model.Enum, as: YangEnum

  describe "Typedef" do
    test "creates with defaults" do
      td = %Typedef{name: "ip-address"}
      assert td.name == "ip-address"
      assert td.type == nil
      assert td.default == nil
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Typedef, %{}) end
    end
  end

  describe "Type" do
    test "creates with defaults" do
      t = %Type{name: "string"}
      assert t.name == "string"
      assert t.patterns == []
      assert t.enum_values == []
      assert t.union_types == []
    end

    test "accepts restriction fields" do
      t = %Type{
        name: "uint32",
        range: %Range{expression: "1..65535"}
      }

      assert t.range.expression == "1..65535"
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Type, %{}) end
    end
  end

  describe "Enum (YangEnum)" do
    test "creates with defaults" do
      e = %YangEnum{name: "active"}
      assert e.name == "active"
      assert e.value == nil
      assert e.if_features == []
    end

    test "accepts value" do
      e = %YangEnum{name: "active", value: 1, status: :current}
      assert e.value == 1
      assert e.status == :current
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(YangEnum, %{}) end
    end
  end

  describe "Bit" do
    test "creates with defaults" do
      b = %Bit{name: "read"}
      assert b.name == "read"
      assert b.position == nil
    end

    test "accepts position" do
      b = %Bit{name: "write", position: 1}
      assert b.position == 1
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Bit, %{}) end
    end
  end

  describe "Identity" do
    test "creates with defaults" do
      i = %Identity{name: "transport"}
      assert i.name == "transport"
      assert i.bases == []
      assert i.if_features == []
    end

    test "accepts bases" do
      i = %Identity{name: "tcp", bases: ["transport"]}
      assert i.bases == ["transport"]
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Identity, %{}) end
    end
  end

  describe "Feature" do
    test "creates with defaults" do
      f = %Feature{name: "ssh"}
      assert f.name == "ssh"
      assert f.if_features == []
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Feature, %{}) end
    end
  end

  describe "Rpc" do
    test "creates with defaults" do
      r = %Rpc{name: "restart"}
      assert r.name == "restart"
      assert r.input == nil
      assert r.output == nil
      assert r.typedefs == []
    end

    test "accepts input and output" do
      r = %Rpc{
        name: "get-config",
        input: %Input{body: [%ExYang.Model.Leaf{name: "source"}]},
        output: %Output{body: [%ExYang.Model.Container{name: "data"}]}
      }

      assert length(r.input.body) == 1
      assert length(r.output.body) == 1
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Rpc, %{}) end
    end
  end

  describe "Action" do
    test "creates with defaults" do
      a = %Action{name: "reset"}
      assert a.name == "reset"
      assert a.input == nil
      assert a.output == nil
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Action, %{}) end
    end
  end

  describe "Input" do
    test "creates with defaults" do
      i = %Input{}
      assert i.must == []
      assert i.body == []
      assert i.typedefs == []
      assert i.groupings == []
    end
  end

  describe "Output" do
    test "creates with defaults" do
      o = %Output{}
      assert o.must == []
      assert o.body == []
      assert o.typedefs == []
      assert o.groupings == []
    end
  end

  describe "Notification" do
    test "creates with defaults" do
      n = %Notification{name: "link-down"}
      assert n.name == "link-down"
      assert n.body == []
      assert n.if_features == []
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Notification, %{}) end
    end
  end

  describe "Must" do
    test "creates with required xpath" do
      m = %Must{xpath: "../enabled = 'true'"}
      assert m.xpath == "../enabled = 'true'"
      assert m.xpath_ast == nil
      assert m.error_message == nil
    end

    test "raises on missing xpath" do
      assert_raise ArgumentError, fn -> struct!(Must, %{}) end
    end
  end

  describe "When" do
    test "creates with required xpath" do
      w = %When{xpath: "../type = 'ethernet'"}
      assert w.xpath == "../type = 'ethernet'"
      assert w.xpath_ast == nil
    end

    test "raises on missing xpath" do
      assert_raise ArgumentError, fn -> struct!(When, %{}) end
    end
  end

  describe "Range" do
    test "creates with required expression" do
      r = %Range{expression: "1..100"}
      assert r.expression == "1..100"
      assert r.error_message == nil
    end

    test "raises on missing expression" do
      assert_raise ArgumentError, fn -> struct!(Range, %{}) end
    end
  end

  describe "Length" do
    test "creates with required expression" do
      l = %Length{expression: "0..255"}
      assert l.expression == "0..255"
      assert l.error_message == nil
    end

    test "raises on missing expression" do
      assert_raise ArgumentError, fn -> struct!(Length, %{}) end
    end
  end

  describe "Pattern" do
    test "creates with required value" do
      p = %Pattern{value: "[0-9a-fA-F]*"}
      assert p.value == "[0-9a-fA-F]*"
      assert p.modifier == nil
    end

    test "accepts invert_match modifier" do
      p = %Pattern{value: ".*", modifier: :invert_match}
      assert p.modifier == :invert_match
    end

    test "raises on missing value" do
      assert_raise ArgumentError, fn -> struct!(Pattern, %{}) end
    end
  end

  describe "ExtensionDef" do
    test "creates with defaults" do
      e = %ExtensionDef{name: "tailf:info"}
      assert e.name == "tailf:info"
      assert e.argument == nil
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(ExtensionDef, %{}) end
    end
  end

  describe "ExtensionUse" do
    test "creates with required keyword" do
      eu = %ExtensionUse{keyword: "tailf:info", argument: "Some help text"}
      assert eu.keyword == "tailf:info"
      assert eu.argument == "Some help text"
      assert eu.sub_statements == []
    end

    test "accepts nested sub_statements" do
      eu = %ExtensionUse{
        keyword: "ext:outer",
        sub_statements: [
          %ExtensionUse{keyword: "ext:inner", argument: "val"}
        ]
      }

      assert length(eu.sub_statements) == 1
    end

    test "raises on missing keyword" do
      assert_raise ArgumentError, fn -> struct!(ExtensionUse, %{}) end
    end
  end
end
