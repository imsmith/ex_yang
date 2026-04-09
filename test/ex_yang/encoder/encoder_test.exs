defmodule ExYang.Encoder.EncoderTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Encoder.Encoder
  alias ExYang.Model.{Module, Container, Leaf, Type, Import, Revision}

  describe "encode/1" do
    test "encodes minimal module" do
      mod = %Module{
        name: "test-module",
        namespace: "urn:example:test",
        prefix: "t",
        yang_version: "1.1"
      }

      {:ok, yang} = Encoder.encode(mod)

      assert yang =~ "module test-module {"
      assert yang =~ ~s(namespace "urn:example:test";)
      assert yang =~ "prefix t;"
      assert yang =~ "yang-version 1.1;"
      assert yang =~ "}"
    end

    test "encodes container with nested leaf" do
      mod = %Module{
        name: "test-module",
        namespace: "urn:example:test",
        prefix: "t",
        body: [
          %Container{
            name: "system",
            body: [
              %Leaf{
                name: "hostname",
                type: %Type{name: "string"}
              }
            ]
          }
        ]
      }

      {:ok, yang} = Encoder.encode(mod)

      assert yang =~ "container system {"
      assert yang =~ "leaf hostname {"
      assert yang =~ "type string;"
      assert yang =~ "}"
    end

    test "encodes imports" do
      mod = %Module{
        name: "test-module",
        namespace: "urn:example:test",
        prefix: "t",
        imports: [
          %Import{
            module: "ietf-yang-types",
            prefix: "yang",
            revision_date: "2013-07-15"
          }
        ]
      }

      {:ok, yang} = Encoder.encode(mod)

      assert yang =~ "import ietf-yang-types {"
      assert yang =~ "prefix yang;"
      assert yang =~ ~s(revision-date 2013-07-15;)
    end

    test "encodes revision with description" do
      mod = %Module{
        name: "test-module",
        namespace: "urn:example:test",
        prefix: "t",
        revisions: [
          %Revision{date: "2024-01-01", description: "Initial revision."}
        ]
      }

      {:ok, yang} = Encoder.encode(mod)

      assert yang =~ "revision 2024-01-01 {"
      assert yang =~ ~s(description "Initial revision.";)
    end

    test "encodes simple revision without block" do
      rev = %Revision{date: "2024-01-01"}
      {:ok, yang} = Encoder.encode(%Module{name: "m", revisions: [rev]})
      assert yang =~ "revision 2024-01-01;"
      refute yang =~ "revision 2024-01-01 {"
    end

    test "round-trip: parse -> encode -> parse produces same structure" do
      source = """
      module round-trip-test {
        yang-version 1.1;
        namespace "urn:example:round-trip";
        prefix rt;

        import ietf-yang-types {
          prefix yang;
        }

        revision 2024-01-01 {
          description "Initial revision.";
        }

        container system {
          leaf hostname {
            type string;
            description "The system hostname.";
          }
          leaf-list dns-server {
            type string;
          }
        }
      }
      """

      {:ok, parsed1} = ExYang.parse(source)
      {:ok, encoded} = Encoder.encode(parsed1)
      {:ok, parsed2} = ExYang.parse(encoded)

      # Compare structurally, ignoring meta/comments
      assert strip_meta(parsed1) == strip_meta(parsed2)
    end

    test "skips nil fields and empty lists" do
      mod = %Module{
        name: "minimal",
        namespace: "urn:example:minimal",
        prefix: "m"
      }

      {:ok, yang} = Encoder.encode(mod)

      refute yang =~ "organization"
      refute yang =~ "contact"
      refute yang =~ "description"
      refute yang =~ "import"
      refute yang =~ "container"
    end

    test "encodes boolean fields" do
      mod = %Module{
        name: "bool-test",
        body: [
          %Leaf{name: "x", type: %Type{name: "string"}, mandatory: true, config: false}
        ]
      }

      {:ok, yang} = Encoder.encode(mod)

      assert yang =~ "mandatory true;"
      assert yang =~ "config false;"
    end
  end

  # Strip meta and comments for structural comparison
  defp strip_meta(%{__struct__: _} = s) do
    s
    |> Map.from_struct()
    |> Map.drop([:meta, :comments])
    |> Enum.map(fn {k, v} -> {k, strip_meta(v)} end)
    |> Enum.into(%{})
    |> Map.put(:__struct__, s.__struct__)
  end

  defp strip_meta(list) when is_list(list), do: Enum.map(list, &strip_meta/1)
  defp strip_meta(other), do: other
end
