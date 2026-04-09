defmodule ExYang.Registry.EctoRegistryTest do
  @moduledoc false
  use ExUnit.Case

  alias ExYang.Registry.EctoRegistry
  alias ExYang.TestRepo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)

    Ecto.Migrator.run(TestRepo, [{0, ExYang.Registry.Migrations.V01}], :up,
      all: true,
      log: false
    )

    :ok
  end

  test "store and fetch round-trip" do
    yang = "module test-reg { namespace \"urn:test\"; prefix t; leaf x { type string; } }"
    {:ok, mod} = ExYang.parse(yang)
    {:ok, id} = EctoRegistry.store(mod, yang, TestRepo)
    assert is_binary(id)

    {:ok, fetched} = EctoRegistry.fetch("test-reg", nil, TestRepo)
    assert fetched.name == "test-reg"
  end

  test "delete module" do
    yang = "module del-test { namespace \"urn:del\"; prefix d; }"
    {:ok, mod} = ExYang.parse(yang)
    {:ok, _} = EctoRegistry.store(mod, yang, TestRepo)

    assert :ok = EctoRegistry.delete("del-test", nil, TestRepo)
    assert :error = EctoRegistry.fetch("del-test", nil, TestRepo)
  end

  test "fetch nonexistent returns :error" do
    assert :error = EctoRegistry.fetch("nonexistent", nil, TestRepo)
  end

  test "search by name pattern" do
    yang = "module search-test { namespace \"urn:search\"; prefix s; }"
    {:ok, mod} = ExYang.parse(yang)
    {:ok, _} = EctoRegistry.store(mod, yang, TestRepo)

    results = EctoRegistry.search([name: "search%"], TestRepo)
    assert length(results) == 1
    assert hd(results).name == "search-test"
  end
end
