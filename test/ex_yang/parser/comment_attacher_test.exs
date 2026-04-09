defmodule ExYang.Parser.CommentAttacherTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ExYang.Parser.CommentAttacher

  describe "attach/3" do
    test "no comments returns statements unchanged" do
      stmts = [{:leaf, "hostname", [], %{line: 1}}]
      assert stmts == CommentAttacher.attach(stmts, [], MapSet.new())
    end

    test "leading comment attached to next statement" do
      stmts = [{:leaf, "hostname", [], %{line: 2}}]
      comments = [{1, " the hostname"}]

      result = CommentAttacher.attach(stmts, comments, MapSet.new())

      assert [{:leaf, "hostname", [], meta}] = result
      assert [%{text: " the hostname", position: :leading}] = meta.comments
    end

    test "inline comment on same line as statement" do
      stmts = [{:leaf, "hostname", [], %{line: 1}}]
      comments = [{1, " inline note"}]

      result = CommentAttacher.attach(stmts, comments, MapSet.new())

      assert [{:leaf, "hostname", [], meta}] = result
      assert [%{text: " inline note", position: :inline}] = meta.comments
    end

    test "floating comment separated by blank line" do
      stmts = [{:leaf, "hostname", [], %{line: 3}}]
      comments = [{1, " floating note"}]
      blank_lines = MapSet.new([2])

      result = CommentAttacher.attach(stmts, comments, blank_lines)

      assert [{:leaf, "hostname", [], meta}] = result
      assert [%{text: " floating note", position: :floating}] = meta.comments
    end

    test "multiple comments on consecutive lines before statement" do
      stmts = [{:leaf, "hostname", [], %{line: 3}}]
      comments = [{1, " first"}, {2, " second"}]

      result = CommentAttacher.attach(stmts, comments, MapSet.new())

      assert [{:leaf, "hostname", [], meta}] = result
      assert length(meta.comments) == 2
      assert Enum.all?(meta.comments, &(&1.position == :leading))
    end

    test "comments distributed across multiple statements" do
      stmts = [
        {:leaf, "a", [], %{line: 2}},
        {:leaf, "b", [], %{line: 4}}
      ]

      comments = [{1, " for a"}, {3, " for b"}]

      result = CommentAttacher.attach(stmts, comments, MapSet.new())

      assert [{:leaf, "a", [], meta_a}, {:leaf, "b", [], meta_b}] = result
      assert [%{text: " for a", position: :leading}] = meta_a.comments
      assert [%{text: " for b", position: :leading}] = meta_b.comments
    end

    test "empty statements returns empty" do
      assert [] == CommentAttacher.attach([], [{1, "orphan"}], MapSet.new())
    end

    test "no meta.comments key when statement has no comments" do
      stmts = [{:leaf, "hostname", [], %{line: 5}}]
      comments = [{1, " early comment"}]
      blank_lines = MapSet.new([2])

      result = CommentAttacher.attach(stmts, comments, blank_lines)

      assert [{:leaf, "hostname", [], meta}] = result
      # This comment is before the statement but separated by blank line — floating
      assert meta.comments == [%{text: " early comment", position: :floating}]
    end
  end
end
