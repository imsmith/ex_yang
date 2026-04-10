defmodule ExYang.Encoder.FormatterTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest ExYang.Encoder.Formatter

  alias ExYang.Encoder.Formatter

  describe "format/1" do
    test "produces canonical output" do
      source = """
      module fmt-test {
        yang-version 1.1;
        namespace "urn:example:fmt";
        prefix ft;

        container config {
          leaf name {
            type string;
          }
        }
      }
      """

      {:ok, parsed} = ExYang.parse(source)
      {:ok, formatted} = Formatter.format(parsed)

      assert formatted =~ "module fmt-test {"
      assert formatted =~ "namespace \"urn:example:fmt\";"
      assert formatted =~ "prefix ft;"
      assert formatted =~ "container config {"
      assert formatted =~ "leaf name {"
      assert formatted =~ "type string;"
    end

    test "format is idempotent" do
      source = """
      module idem-test {
        yang-version 1.1;
        namespace "urn:example:idem";
        prefix it;

        container sys {
          leaf host {
            type string;
            description "Host name.";
          }
        }
      }
      """

      {:ok, parsed1} = ExYang.parse(source)
      {:ok, formatted1} = Formatter.format(parsed1)
      {:ok, parsed2} = ExYang.parse(formatted1)
      {:ok, formatted2} = Formatter.format(parsed2)

      assert formatted1 == formatted2
    end
  end
end
