defmodule ExYang.Model.DataDefTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Model.{Container, Leaf, LeafList, List, Choice, Case, AnyData, AnyXml}

  describe "Container" do
    test "creates with defaults" do
      c = %Container{name: "system"}
      assert c.name == "system"
      assert c.config == nil
      assert c.presence == nil
      assert c.must == []
      assert c.body == []
      assert c.meta == %{}
    end

    test "accepts nested body" do
      c = %Container{
        name: "system",
        body: [%Leaf{name: "hostname"}],
        presence: "Enables system config"
      }

      assert length(c.body) == 1
      assert c.presence == "Enables system config"
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Container, %{}) end
    end
  end

  describe "Leaf" do
    test "creates with defaults" do
      l = %Leaf{name: "hostname"}
      assert l.name == "hostname"
      assert l.type == nil
      assert l.mandatory == nil
      assert l.must == []
    end

    test "accepts all fields" do
      l = %Leaf{
        name: "hostname",
        type: %ExYang.Model.Type{name: "string"},
        default: "localhost",
        config: true,
        mandatory: false,
        units: "bytes",
        status: :current
      }

      assert l.default == "localhost"
      assert l.config == true
      assert l.units == "bytes"
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Leaf, %{}) end
    end
  end

  describe "LeafList" do
    test "creates with defaults" do
      ll = %LeafList{name: "search"}
      assert ll.name == "search"
      assert ll.min_elements == nil
      assert ll.max_elements == nil
      assert ll.ordered_by == nil
    end

    test "accepts element constraints" do
      ll = %LeafList{name: "search", min_elements: 1, max_elements: 10, ordered_by: :user}
      assert ll.min_elements == 1
      assert ll.max_elements == 10
      assert ll.ordered_by == :user
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(LeafList, %{}) end
    end
  end

  describe "List" do
    test "creates with defaults" do
      l = %List{name: "interface"}
      assert l.name == "interface"
      assert l.key == nil
      assert l.unique == []
      assert l.body == []
    end

    test "accepts key and children" do
      l = %List{
        name: "interface",
        key: "name",
        body: [%Leaf{name: "name"}, %Leaf{name: "mtu"}]
      }

      assert l.key == "name"
      assert length(l.body) == 2
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(List, %{}) end
    end
  end

  describe "Choice" do
    test "creates with defaults" do
      ch = %Choice{name: "transfer"}
      assert ch.name == "transfer"
      assert ch.cases == []
      assert ch.mandatory == nil
    end

    test "accepts cases" do
      ch = %Choice{
        name: "transfer",
        cases: [%Case{name: "ftp"}, %Case{name: "sftp"}]
      }

      assert length(ch.cases) == 2
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Choice, %{}) end
    end
  end

  describe "Case" do
    test "creates with defaults" do
      c = %Case{name: "ftp"}
      assert c.name == "ftp"
      assert c.body == []
      assert c.if_features == []
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Case, %{}) end
    end
  end

  describe "AnyData" do
    test "creates with defaults" do
      ad = %AnyData{name: "data"}
      assert ad.name == "data"
      assert ad.config == nil
      assert ad.mandatory == nil
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(AnyData, %{}) end
    end
  end

  describe "AnyXml" do
    test "creates with defaults" do
      ax = %AnyXml{name: "payload"}
      assert ax.name == "payload"
      assert ax.config == nil
      assert ax.must == []
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(AnyXml, %{}) end
    end
  end
end
