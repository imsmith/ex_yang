defmodule ExYang.Parser.GrammarTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Parser.Grammar

  describe "parse/1" do
    test "simple statement with keyword arg and semicolon" do
      assert {:ok, [{:namespace, "urn:example:system", [], %{line: 1}}], _, _} =
               Grammar.parse(~s(namespace "urn:example:system";))
    end

    test "simple statement with unquoted arg" do
      assert {:ok, [{:type, "string", [], %{line: 1}}], _, _} =
               Grammar.parse("type string;")
    end

    test "no-argument statement with semicolon" do
      assert {:ok, [{:input, nil, [], %{line: 1}}], _, _} =
               Grammar.parse("input;")
    end

    test "block statement with argument" do
      input = ~s(container system { })
      assert {:ok, [{:container, "system", [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "block statement without argument" do
      input = "input { }"
      assert {:ok, [{:input, nil, [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "nested blocks" do
      input = """
      container system {
        leaf hostname {
          type string;
        }
      }
      """

      assert {:ok, [{:container, "system", subs, %{line: 1}}], _, _} = Grammar.parse(input)
      assert [{:leaf, "hostname", leaf_subs, %{line: 2}}] = subs
      assert [{:type, "string", [], %{line: 3}}] = leaf_subs
    end

    test "multiple top-level statements" do
      input = """
      namespace "urn:example";
      prefix ex;
      """

      assert {:ok, stmts, _, _} = Grammar.parse(input)
      assert length(stmts) == 2
      assert {:namespace, "urn:example", [], _} = Enum.at(stmts, 0)
      assert {:prefix, "ex", [], _} = Enum.at(stmts, 1)
    end

    test "string concatenation" do
      input = ~s(description "hello " + "world";)
      assert {:ok, [{:description, "hello world", [], meta}], _, _} = Grammar.parse(input)
      assert meta.string_fragments == ["hello ", "world"]
    end

    test "prefixed keyword" do
      input = "if:interfaces;"
      assert {:ok, [{{:if, :interfaces}, nil, [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "prefixed keyword as block" do
      input = "ex:my-extension arg { }"
      assert {:ok, [{{:ex, :"my-extension"}, "arg", [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "keyword argument used as unquoted string" do
      input = "default true;"
      assert {:ok, [{:default, "true", [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "date as argument" do
      input = ~s(revision 2018-02-20;)
      assert {:ok, [{:revision, "2018-02-20", [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "error on unclosed brace" do
      input = "container system {"
      assert {:error, reason} = Grammar.parse(input)
      assert reason =~ "unclosed"
    end

    test "error on unexpected token" do
      input = "{ leaf }"
      assert {:error, reason} = Grammar.parse(input)
      assert reason =~ "expected keyword"
    end

    test "error on missing semicolon or brace after argument" do
      input = "type string type"
      assert {:error, _reason} = Grammar.parse(input)
    end

    test "comments are extracted" do
      input = """
      // this is a comment
      leaf hostname {
        type string;
      }
      """

      assert {:ok, _stmts, comments, _blank_lines} = Grammar.parse(input)
      assert [{1, " this is a comment"}] = comments
    end

    test "blank lines are detected" do
      input = "leaf a;\n\nleaf b;"
      assert {:ok, _stmts, _comments, blank_lines} = Grammar.parse(input)
      assert MapSet.member?(blank_lines, 2)
    end

    test "minimal YANG module" do
      input = """
      module example-system {
        namespace "urn:example:system";
        prefix sys;

        container system {
          leaf hostname {
            type string;
            description "The hostname.";
          }
        }
      }
      """

      assert {:ok, [{:module, "example-system", subs, %{line: 1}}], _, _} = Grammar.parse(input)
      assert length(subs) == 3

      assert {:namespace, "urn:example:system", [], _} = Enum.at(subs, 0)
      assert {:prefix, "sys", [], _} = Enum.at(subs, 1)
      assert {:container, "system", container_subs, _} = Enum.at(subs, 2)
      assert [{:leaf, "hostname", leaf_subs, _}] = container_subs
      assert length(leaf_subs) == 2
    end

    test "single-quoted argument" do
      input = "pattern '[0-9]+';"
      assert {:ok, [{:pattern, "[0-9]+", [], %{line: 1}}], _, _} = Grammar.parse(input)
    end

    test "mixed string concatenation" do
      input = ~s(description "hello " + 'world';)
      assert {:ok, [{:description, "hello world", [], meta}], _, _} = Grammar.parse(input)
      assert meta.string_fragments
    end
  end
end
