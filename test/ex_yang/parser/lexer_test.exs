defmodule ExYang.Parser.LexerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Parser.Lexer

  describe "tokenize/1" do
    test "simple keyword" do
      assert {:ok, [{:keyword, %{line: 1, column: 1}, "module"}]} = Lexer.tokenize("module")
    end

    test "hyphenated keyword" do
      assert {:ok, [{:keyword, %{line: 1, column: 1}, "leaf-list"}]} = Lexer.tokenize("leaf-list")
    end

    test "dotted keyword / date" do
      assert {:ok, [{:keyword, %{line: 1, column: 1}, "2018-02-20"}]} =
               Lexer.tokenize("2018-02-20")
    end

    test "prefixed keyword" do
      assert {:ok, [{:keyword, %{line: 1, column: 1}, {"if", "interfaces"}}]} =
               Lexer.tokenize("if:interfaces")
    end

    test "double-quoted string" do
      assert {:ok, [{:dq_string, %{line: 1, column: 1}, "hello world"}]} =
               Lexer.tokenize(~s("hello world"))
    end

    test "double-quoted string with escapes" do
      assert {:ok, [{:dq_string, %{line: 1, column: 1}, "a\nb\\c\"d\te"}]} =
               Lexer.tokenize(~s("a\\nb\\\\c\\"d\\te"))
    end

    test "single-quoted string" do
      assert {:ok, [{:sq_string, %{line: 1, column: 1}, "hello"}]} =
               Lexer.tokenize("'hello'")
    end

    test "single-quoted string preserves backslashes" do
      assert {:ok, [{:sq_string, %{line: 1, column: 1}, "a\\nb"}]} =
               Lexer.tokenize("'a\\nb'")
    end

    test "empty double-quoted string" do
      assert {:ok, [{:dq_string, %{line: 1, column: 1}, ""}]} = Lexer.tokenize(~s(""))
    end

    test "empty single-quoted string" do
      assert {:ok, [{:sq_string, %{line: 1, column: 1}, ""}]} = Lexer.tokenize("''")
    end

    test "punctuation tokens" do
      assert {:ok, tokens} = Lexer.tokenize("{ } ; +")

      types = Enum.map(tokens, &elem(&1, 0))
      assert types == [:open_brace, :whitespace, :close_brace, :whitespace, :semicolon, :whitespace, :plus]
    end

    test "line comment" do
      assert {:ok, tokens} = Lexer.tokenize("// this is a comment\nleaf")

      assert [{:line_comment, %{line: 1}, " this is a comment"},
              {:newline, %{line: 1}, "\n"},
              {:keyword, %{line: 2, column: 1}, "leaf"}] = tokens
    end

    test "block comment" do
      assert {:ok, tokens} = Lexer.tokenize("/* block */leaf")

      assert [{:block_comment, %{line: 1, column: 1}, " block "},
              {:keyword, %{line: 1}, "leaf"}] = tokens
    end

    test "multiline block comment" do
      input = "/* line1\nline2 */leaf"
      assert {:ok, tokens} = Lexer.tokenize(input)

      assert [{:block_comment, %{line: 1}, " line1\nline2 "},
              {:keyword, %{line: 2}, "leaf"}] = tokens
    end

    test "whitespace and newlines preserved" do
      assert {:ok, tokens} = Lexer.tokenize("  \n\t")

      types = Enum.map(tokens, &elem(&1, 0))
      assert types == [:whitespace, :newline, :whitespace]
    end

    test "keyword followed by string and semicolon" do
      assert {:ok, tokens} = Lexer.tokenize(~s(description "hello";))

      relevant = Enum.reject(tokens, fn {t, _, _} -> t in [:whitespace, :newline] end)

      assert [{:keyword, _, "description"},
              {:dq_string, _, "hello"},
              {:semicolon, _, _}] = relevant
    end

    test "plus token for concatenation" do
      assert {:ok, tokens} = Lexer.tokenize(~s("a" + "b"))

      relevant = Enum.reject(tokens, fn {t, _, _} -> t in [:whitespace, :newline] end)

      assert [{:dq_string, _, "a"},
              {:plus, _, _},
              {:dq_string, _, "b"}] = relevant
    end

    test "full simple statement" do
      input = ~s(namespace "urn:example:system";)
      assert {:ok, tokens} = Lexer.tokenize(input)

      relevant = Enum.reject(tokens, fn {t, _, _} -> t in [:whitespace, :newline] end)

      assert [{:keyword, _, "namespace"},
              {:dq_string, _, "urn:example:system"},
              {:semicolon, _, _}] = relevant
    end

    test "block with body" do
      input = """
      container system {
        leaf hostname {
          type string;
        }
      }
      """

      assert {:ok, tokens} = Lexer.tokenize(input)
      keywords = for {:keyword, _, v} <- tokens, do: v
      assert keywords == ["container", "system", "leaf", "hostname", "type", "string"]
    end

    test "line tracking across newlines" do
      input = "a\nb\nc"
      assert {:ok, tokens} = Lexer.tokenize(input)

      keyword_lines = for {:keyword, meta, _v} <- tokens, do: meta.line
      assert keyword_lines == [1, 2, 3]
    end

    test "error on invalid character" do
      assert {:error, _reason} = Lexer.tokenize("module @invalid")
    end

    test "multiline double-quoted string" do
      input = ~s("line1\nline2")
      assert {:ok, [{:dq_string, %{line: 1}, "line1\nline2"}]} = Lexer.tokenize(input)
    end

    test "keyword starting with digit" do
      assert {:ok, [{:keyword, _, "1999"}]} = Lexer.tokenize("1999")
    end

    test "keyword with underscore" do
      assert {:ok, [{:keyword, _, "my_leaf"}]} = Lexer.tokenize("my_leaf")
    end

    test "keyword starting with underscore" do
      assert {:ok, [{:keyword, _, "_private"}]} = Lexer.tokenize("_private")
    end

    test "complex prefixed keyword" do
      assert {:ok, [{:keyword, _, {"ietf-ip", "ipv4"}}]} = Lexer.tokenize("ietf-ip:ipv4")
    end
  end
end
