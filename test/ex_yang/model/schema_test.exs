defmodule ExYang.Model.SchemaTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Model.{Grouping, Uses, Refine, Augment, Deviation, Deviate}

  describe "Grouping" do
    test "creates with defaults" do
      g = %Grouping{name: "address"}
      assert g.name == "address"
      assert g.typedefs == []
      assert g.groupings == []
      assert g.body == []
    end

    test "raises on missing name" do
      assert_raise ArgumentError, fn -> struct!(Grouping, %{}) end
    end
  end

  describe "Uses" do
    test "creates with required grouping" do
      u = %Uses{grouping: "address"}
      assert u.grouping == "address"
      assert u.refines == []
      assert u.augments == []
    end

    test "raises on missing grouping" do
      assert_raise ArgumentError, fn -> struct!(Uses, %{}) end
    end
  end

  describe "Refine" do
    test "creates with required target_node" do
      r = %Refine{target_node: "address/street"}
      assert r.target_node == "address/street"
      assert r.config == nil
      assert r.must == []
    end

    test "accepts constraint overrides" do
      r = %Refine{
        target_node: "address/zip",
        mandatory: true,
        config: false,
        default: "00000"
      }

      assert r.mandatory == true
      assert r.config == false
      assert r.default == "00000"
    end

    test "raises on missing target_node" do
      assert_raise ArgumentError, fn -> struct!(Refine, %{}) end
    end
  end

  describe "Augment" do
    test "creates with required target_node" do
      a = %Augment{target_node: "/if:interfaces/if:interface"}
      assert a.target_node == "/if:interfaces/if:interface"
      assert a.body == []
      assert a.if_features == []
    end

    test "raises on missing target_node" do
      assert_raise ArgumentError, fn -> struct!(Augment, %{}) end
    end
  end

  describe "Deviation" do
    test "creates with required target_node" do
      d = %Deviation{target_node: "/sys:system/sys:ntp"}
      assert d.target_node == "/sys:system/sys:ntp"
      assert d.deviates == []
    end

    test "raises on missing target_node" do
      assert_raise ArgumentError, fn -> struct!(Deviation, %{}) end
    end
  end

  describe "Deviate" do
    test "creates with required type" do
      d = %Deviate{type: :not_supported}
      assert d.type == :not_supported
      assert d.must == []
      assert d.unique == []
    end

    test "accepts all deviate types" do
      for t <- [:not_supported, :add, :replace, :delete] do
        d = %Deviate{type: t}
        assert d.type == t
      end
    end

    test "raises on missing type" do
      assert_raise ArgumentError, fn -> struct!(Deviate, %{}) end
    end
  end
end
