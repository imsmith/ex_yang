defmodule ExYang.Parser.CommentAttacher do
  @moduledoc """
  Attaches comments to their nearest statement nodes in the generic tree.

  Rules:
  - A comment on the line immediately before a statement (no blank line between) → `:leading`
  - A comment on the same line as a statement → `:inline`
  - A comment separated from the next statement by a blank line → `:floating`
  """

  @type statement :: {atom() | {atom(), atom()}, String.t() | nil, [statement()], map()}
  @type comment :: {pos_integer(), String.t()}

  @doc """
  Attach comments to statement nodes.

  - `statements` — list of `{keyword, arg, subs, meta}` tuples
  - `comments` — list of `{line_number, text}` tuples
  - `blank_lines` — `MapSet` of blank line numbers

  Returns the statements with comments attached in `meta.comments`.
  """
  @spec attach([statement()], [comment()], MapSet.t()) :: [statement()]
  def attach(statements, [], _blank_lines), do: statements
  def attach([], _comments, _blank_lines), do: []

  def attach(statements, comments, blank_lines) do
    # Sort comments by line
    comments = Enum.sort_by(comments, &elem(&1, 0))

    # Build a map of statement line -> statement index for top-level
    # We process recursively: for each level, distribute comments among statements

    attach_level(statements, comments, blank_lines)
  end

  # ---------------------------------------------------------------------------
  # Core algorithm
  # ---------------------------------------------------------------------------

  defp attach_level([], _comments, _blank_lines), do: []

  defp attach_level(statements, comments, blank_lines) do
    # For each statement, determine which comments belong to it
    # We walk statements and comments together in line order

    {result, _remaining_comments} =
      statements
      |> Enum.with_index()
      |> Enum.reduce({[], comments}, fn {stmt, idx}, {acc, remaining_comments} ->
        {keyword, arg, subs, meta} = stmt
        stmt_line = meta.line

        # Find the next statement's line (for bounding)
        next_stmt_line = find_next_stmt_line(statements, idx)

        # Partition remaining comments into: before this stmt, on this stmt, after
        {before_comments, on_line_comments, rest} =
          partition_comments(remaining_comments, stmt_line, next_stmt_line)

        # Classify before-comments as leading or floating
        classified =
          classify_before_comments(before_comments, stmt_line, blank_lines) ++
            Enum.map(on_line_comments, fn {_line, text} ->
              %{text: text, position: :inline}
            end)

        # Recurse into sub-statements if any
        # Sub-statement comments are those between { and }
        # For now, we don't split comments into sub-levels (comments within blocks
        # should already be associated with the sub-statements at their level)
        new_subs =
          if subs != [] do
            # We don't have sub-comments extraction here — the grammar doesn't
            # preserve comment tokens inside blocks. Sub-statement comment attachment
            # requires the comments to be filtered by line range.
            sub_start = stmt_line
            sub_end = next_stmt_line || :infinity

            sub_comments =
              rest
              |> Enum.filter(fn {line, _text} ->
                line > sub_start and (sub_end == :infinity or line < sub_end)
              end)

            if sub_comments != [] do
              attach_level(subs, sub_comments, blank_lines)
            else
              subs
            end
          else
            subs
          end

        new_meta =
          if classified != [] do
            Map.put(meta, :comments, classified)
          else
            meta
          end

        new_stmt = {keyword, arg, new_subs, new_meta}
        {[new_stmt | acc], rest}
      end)

    Enum.reverse(result)
  end

  defp find_next_stmt_line(statements, current_idx) do
    if current_idx + 1 < length(statements) do
      {_kw, _arg, _subs, meta} = Enum.at(statements, current_idx + 1)
      meta.line
    else
      nil
    end
  end

  defp partition_comments(comments, stmt_line, next_stmt_line) do
    {before, rest} = Enum.split_while(comments, fn {line, _} -> line < stmt_line end)
    {on_line, rest2} = Enum.split_while(rest, fn {line, _} -> line == stmt_line end)

    # Don't consume comments that belong to the next statement
    rest3 =
      case next_stmt_line do
        nil -> rest2
        _ -> rest2
      end

    {before, on_line, rest3}
  end

  defp classify_before_comments([], _stmt_line, _blank_lines), do: []

  defp classify_before_comments(comments, stmt_line, blank_lines) do
    Enum.map(comments, fn {comment_line, text} ->
      # Check if there's a blank line between the comment and the statement
      has_blank_between =
        Enum.any?((comment_line + 1)..(stmt_line - 1)//1, fn line ->
          MapSet.member?(blank_lines, line)
        end)

      position = if has_blank_between, do: :floating, else: :leading
      %{text: text, position: position}
    end)
  end
end
