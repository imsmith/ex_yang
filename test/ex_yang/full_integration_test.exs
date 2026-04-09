defmodule ExYang.FullIntegrationTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "parse -> resolve -> encode round-trip" do
    types_source = File.read!("test/fixtures/ietf-yang-types@2013-07-15.yang")
    {:ok, types_mod} = ExYang.parse(types_source)

    yang = """
    module my-app {
      namespace "urn:example:my-app";
      prefix app;

      import ietf-yang-types {
        prefix yang;
      }

      typedef app-name {
        type string;
      }

      container config {
        leaf name {
          type app-name;
        }
        leaf created {
          type yang:date-and-time;
        }
      }
    }
    """

    {:ok, mod} = ExYang.parse(yang)
    registry = %{"ietf-yang-types" => types_mod}
    {:ok, resolved} = ExYang.resolve(mod, registry)
    assert resolved.module.name == "my-app"

    {:ok, output} = ExYang.encode(resolved.module)
    assert {:ok, _} = ExYang.parse(output)

    {:ok, formatted} = ExYang.format(resolved.module)
    assert {:ok, _} = ExYang.parse(formatted)
  end

  test "diagnostic formatting" do
    diag = %ExYang.Diagnostic{
      severity: :error,
      phase: :validation,
      message: "missing mandatory sub-statement 'type'",
      file: "test.yang",
      line: 42,
      column: 5,
      context: ["module test", "container config", "leaf name"]
    }

    formatted = ExYang.Diagnostic.format(diag)
    assert formatted =~ "error[validation]"
    assert formatted =~ "test.yang:42:5"
    assert formatted =~ "module test > container config > leaf name"
  end
end
