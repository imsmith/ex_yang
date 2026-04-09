defmodule ExYang.Model.ModuleTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Model.{Module, Submodule, Import, Include, Revision, BelongsTo}

  describe "Import" do
    test "creates with required module field" do
      imp = %Import{module: "ietf-inet-types"}
      assert imp.module == "ietf-inet-types"
      assert imp.prefix == nil
      assert imp.meta == %{}
      assert imp.comments == []
    end

    test "creates with all fields" do
      imp = %Import{
        module: "ietf-inet-types",
        prefix: "inet",
        revision_date: "2013-07-15",
        description: "Internet types",
        reference: "RFC 6991"
      }

      assert imp.prefix == "inet"
      assert imp.revision_date == "2013-07-15"
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(Import, %{}) end
    end
  end

  describe "Include" do
    test "creates with required module field" do
      inc = %Include{module: "my-submodule"}
      assert inc.module == "my-submodule"
      assert inc.revision_date == nil
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(Include, %{}) end
    end
  end

  describe "Revision" do
    test "creates with required date field" do
      rev = %Revision{date: "2024-01-01"}
      assert rev.date == "2024-01-01"
      assert rev.description == nil
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(Revision, %{}) end
    end
  end

  describe "BelongsTo" do
    test "creates with required module field" do
      bt = %BelongsTo{module: "parent-module", prefix: "pm"}
      assert bt.module == "parent-module"
      assert bt.prefix == "pm"
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(BelongsTo, %{}) end
    end
  end

  describe "Module" do
    test "creates with required name field and list defaults" do
      mod = %Module{name: "ietf-interfaces"}
      assert mod.name == "ietf-interfaces"
      assert mod.imports == []
      assert mod.includes == []
      assert mod.revisions == []
      assert mod.body == []
      assert mod.meta == %{}
      assert mod.comments == []
    end

    test "Access.fetch/2 works" do
      mod = %Module{name: "test", namespace: "urn:test"}
      assert mod[:name] == "test"
      assert mod[:namespace] == "urn:test"
      assert mod[:nonexistent] == nil
    end

    test "get_in/2 works" do
      mod = %Module{name: "test", meta: %{source: "file.yang"}}
      assert get_in(mod, [:meta, :source]) == "file.yang"
    end

    test "put_in/3 works" do
      mod = %Module{name: "test"}
      updated = put_in(mod[:namespace], "urn:test")
      assert updated.namespace == "urn:test"
    end

    test "pop/2 works" do
      mod = %Module{name: "test", namespace: "urn:test"}
      {val, updated} = Access.pop(mod, :namespace)
      assert val == "urn:test"
      assert updated.namespace == nil
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(Module, %{}) end
    end
  end

  describe "Submodule" do
    test "creates with required name and optional belongs_to" do
      sub = %Submodule{
        name: "my-sub",
        belongs_to: %BelongsTo{module: "parent", prefix: "p"}
      }

      assert sub.name == "my-sub"
      assert sub.belongs_to.module == "parent"
    end

    test "Access behaviour works" do
      sub = %Submodule{name: "sub"}
      assert sub[:name] == "sub"

      updated = put_in(sub[:yang_version], "1.1")
      assert updated.yang_version == "1.1"
    end

    test "raises on missing required field" do
      assert_raise ArgumentError, fn -> struct!(Submodule, %{}) end
    end
  end
end
