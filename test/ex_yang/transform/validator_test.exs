defmodule ExYang.Transform.ValidatorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest ExYang.Transform.Validator

  alias ExYang.Transform.Validator
  alias ExYang.Model.{Module, Submodule, Leaf, LeafList, Typedef, Type, BelongsTo, Container}

  @meta %{line: 1, column: 1}

  describe "validate/1" do
    test "valid module passes" do
      m = %Module{
        name: "test",
        namespace: "urn:example:test",
        prefix: "t",
        meta: @meta
      }

      assert {:ok, ^m} = Validator.validate(m)
    end

    test "module missing namespace fails" do
      m = %Module{name: "test", prefix: "t", meta: @meta}

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "namespace"
      assert diag.severity == :error
      assert diag.phase == :validation
    end

    test "module missing prefix fails" do
      m = %Module{name: "test", namespace: "urn:example:test", meta: @meta}

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "prefix"
    end

    test "module missing both namespace and prefix returns two errors" do
      m = %Module{name: "test", meta: @meta}

      assert {:error, diags} = Validator.validate(m)
      assert length(diags) == 2
    end

    test "submodule missing belongs_to fails" do
      m = %Submodule{name: "test-sub", meta: @meta}

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "belongs-to"
    end

    test "valid submodule passes" do
      m = %Submodule{
        name: "test-sub",
        belongs_to: %BelongsTo{module: "test", prefix: "t", meta: @meta},
        meta: @meta
      }

      assert {:ok, ^m} = Validator.validate(m)
    end

    test "leaf missing type fails" do
      m = %Module{
        name: "test",
        namespace: "urn:example:test",
        prefix: "t",
        body: [%Leaf{name: "bad-leaf", meta: @meta}],
        meta: @meta
      }

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "type"
    end

    test "leaf-list missing type fails" do
      m = %Module{
        name: "test",
        namespace: "urn:example:test",
        prefix: "t",
        body: [%LeafList{name: "bad-ll", meta: @meta}],
        meta: @meta
      }

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "type"
    end

    test "typedef missing type fails" do
      m = %Module{
        name: "test",
        namespace: "urn:example:test",
        prefix: "t",
        typedefs: [%Typedef{name: "bad-td", meta: @meta}],
        meta: @meta
      }

      assert {:error, [diag]} = Validator.validate(m)
      assert diag.message =~ "type"
    end

    test "nested valid structure passes" do
      m = %Module{
        name: "test",
        namespace: "urn:example:test",
        prefix: "t",
        body: [
          %Container{
            name: "config",
            body: [
              %Leaf{name: "hostname", type: %Type{name: "string", meta: @meta}, meta: @meta}
            ],
            meta: @meta
          }
        ],
        meta: @meta
      }

      assert {:ok, ^m} = Validator.validate(m)
    end
  end
end
