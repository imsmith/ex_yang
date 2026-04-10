defmodule ExYang.Parser.Grammar do
  @moduledoc """
  Builds a generic statement tree from YANG source text.

  Each node in the tree is a tuple:

      {keyword, argument, sub_statements, meta}

  Where:
  - `keyword` — atom or `{atom, atom}` for prefixed keywords
  - `argument` — `nil` or string (concatenation resolved)
  - `sub_statements` — list of child tuples
  - `meta` — `%{line: n}` minimum
  """

  alias ExYang.Parser.Lexer

  @type statement :: {keyword_t(), String.t() | nil, [statement()], map()}
  @type keyword_t :: atom() | {atom(), atom()}

  @doc """
  Parse a YANG source string into a generic statement tree.

  Returns `{:ok, statements, comments, blank_lines}` or `{:error, reason}`.

  The extra `comments` and `blank_lines` are returned for the comment attacher.

  ## Examples

      iex> {:ok, stmts, _, _} = ExYang.Parser.Grammar.parse("leaf name { type string; }")
      iex> [{:leaf, "name", [{:type, "string", [], _}], _}] = stmts
      iex> length(stmts)
      1
  """
  @spec parse(String.t()) :: {:ok, [statement()]} | {:error, String.t()}
  def parse(input) do
    with {:ok, tokens} <- Lexer.tokenize(input) do
      comments = extract_comments(tokens)
      blank_lines = extract_blank_lines(tokens)
      stream = strip_trivia(tokens)

      case parse_statements(stream, []) do
        {:ok, stmts, []} ->
          {:ok, stmts, comments, blank_lines}

        {:ok, _stmts, remaining} ->
          {type, meta, _val} = hd(remaining)
          {:error, "unexpected token #{type} at line #{meta.line}"}

        {:error, _} = err ->
          err
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Token filtering
  # ---------------------------------------------------------------------------

  defp strip_trivia(tokens) do
    Enum.reject(tokens, fn {type, _meta, _val} ->
      type in [:whitespace, :newline, :line_comment, :block_comment]
    end)
  end

  defp extract_comments(tokens) do
    tokens
    |> Enum.filter(fn {type, _meta, _val} -> type in [:line_comment, :block_comment] end)
    |> Enum.map(fn {_type, meta, text} -> {meta.line, text} end)
  end

  defp extract_blank_lines(tokens) do
    # A blank line is a newline that follows another newline (possibly with only whitespace between)
    # We scan the tokens and track consecutive newlines
    tokens
    |> find_blank_lines(nil, MapSet.new())
  end

  defp find_blank_lines([], _prev, acc), do: acc

  defp find_blank_lines([{:newline, meta, _} | rest], prev_newline_line, acc) do
    case prev_newline_line do
      nil ->
        find_blank_lines(rest, meta.line, acc)

      _line ->
        # This newline follows a previous newline (possibly with whitespace between)
        # The blank line is at the current line
        find_blank_lines(rest, meta.line, MapSet.put(acc, meta.line))
    end
  end

  defp find_blank_lines([{:whitespace, _meta, _} | rest], prev, acc) do
    # Whitespace doesn't break the newline chain
    find_blank_lines(rest, prev, acc)
  end

  defp find_blank_lines([_ | rest], _prev, acc) do
    find_blank_lines(rest, nil, acc)
  end

  # ---------------------------------------------------------------------------
  # Recursive descent parser
  # ---------------------------------------------------------------------------

  defp parse_statements([], acc), do: {:ok, Enum.reverse(acc), []}

  defp parse_statements([{:close_brace, _meta, _} | _] = stream, acc) do
    {:ok, Enum.reverse(acc), stream}
  end

  defp parse_statements(stream, acc) do
    case parse_statement(stream) do
      {:ok, stmt, rest} ->
        parse_statements(rest, [stmt | acc])

      {:error, _} = err ->
        err
    end
  end

  defp parse_statement([{:keyword, meta, kw_val} | rest]) do
    keyword = to_keyword(kw_val)
    line = meta.line

    case rest do
      # keyword ;
      [{:semicolon, _meta, _} | rest2] ->
        {:ok, {keyword, nil, [], %{line: line}}, rest2}

      # keyword { ... }
      [{:open_brace, _meta, _} | rest2] ->
        parse_block_body(keyword, nil, line, rest2, %{})

      # keyword argument ...
      [{type, _ameta, _aval} | _] when type in [:keyword, :dq_string, :sq_string] ->
        case parse_argument(rest) do
          {:ok, arg, extra_meta, rest2} ->
            case rest2 do
              [{:semicolon, _meta, _} | rest3] ->
                {:ok, {keyword, arg, [], Map.merge(%{line: line}, extra_meta)}, rest3}

              [{:open_brace, _meta, _} | rest3] ->
                parse_block_body(keyword, arg, line, rest3, extra_meta)

              [] ->
                {:error, "unexpected end of input after argument at line #{line}"}

              [{bad_type, bad_meta, _} | _] ->
                {:error, "expected ';' or '{' after argument, got #{bad_type} at line #{bad_meta.line}"}
            end

          {:error, _} = err ->
            err
        end

      [] ->
        {:error, "unexpected end of input after keyword at line #{line}"}

      [{bad_type, bad_meta, _} | _] ->
        {:error, "unexpected token #{bad_type} at line #{bad_meta.line}"}
    end
  end

  defp parse_statement([{type, meta, _} | _]) do
    {:error, "expected keyword, got #{type} at line #{meta.line}"}
  end

  defp parse_statement([]) do
    {:error, "unexpected end of input"}
  end

  defp parse_block_body(keyword, arg, line, tokens, extra_meta) do
    case parse_statements(tokens, []) do
      {:ok, subs, [{:close_brace, _meta, _} | rest]} ->
        {:ok, {keyword, arg, subs, Map.merge(%{line: line}, extra_meta)}, rest}

      {:ok, _subs, []} ->
        {:error, "unclosed block for #{inspect(keyword)} starting at line #{line}"}

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Argument parsing (with string concatenation)
  # ---------------------------------------------------------------------------

  defp parse_argument(tokens) do
    case tokens do
      [{:keyword, _meta, val} | rest] ->
        arg = keyword_to_string(val)
        {:ok, arg, %{}, rest}

      [{type, _meta, val} | rest] when type in [:dq_string, :sq_string] ->
        # Check for concatenation
        maybe_concat(val, [val], rest)

      _ ->
        {:error, "expected argument"}
    end
  end

  defp maybe_concat(accumulated, fragments, [{:plus, _meta, _} | rest]) do
    case rest do
      [{type, _meta, val} | rest2] when type in [:dq_string, :sq_string] ->
        maybe_concat(accumulated <> val, fragments ++ [val], rest2)

      _ ->
        {:error, "expected string after '+' in concatenation"}
    end
  end

  defp maybe_concat(accumulated, fragments, rest) do
    extra_meta =
      if length(fragments) > 1 do
        %{string_fragments: fragments}
      else
        %{}
      end

    {:ok, accumulated, extra_meta, rest}
  end

  # ---------------------------------------------------------------------------
  # Keyword conversion
  # ---------------------------------------------------------------------------

  defp to_keyword({prefix, name}) do
    {String.to_atom(prefix), String.to_atom(name)}
  end

  defp to_keyword(name) when is_binary(name) do
    String.to_atom(name)
  end

  defp keyword_to_string({prefix, name}), do: prefix <> ":" <> name
  defp keyword_to_string(name) when is_binary(name), do: name
end
