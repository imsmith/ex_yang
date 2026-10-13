defmodule ExYang.Parser.Grammar do
  @moduledoc """
  Builds a generic statement tree from YANG source text.

  Each node in the tree is a tuple:

      {keyword, argument, sub_statements, meta}

  Where:
  - `keyword` — atom for RFC 7950 keywords, `{prefix, name}` strings for prefixed keywords
  - `argument` — `nil` or string (concatenation resolved)
  - `sub_statements` — list of child tuples
  - `meta` — `%{line: n}` minimum
  """

  alias ExYang.Parser.Lexer

  @typedoc "A generic statement node: `{keyword, argument, sub_statements, meta}`."
  @type statement :: {keyword_t(), String.t() | nil, [statement()], meta()}

  @typedoc """
  Statement keyword. RFC 7950 keywords become atoms; prefixed extension
  keywords stay as `{prefix, name}` string tuples; unknown unprefixed
  keywords stay strings (no atom flooding from user input).
  """
  @type keyword_t :: atom() | String.t() | {String.t(), String.t()}

  @typedoc "Statement metadata: source line plus optional `string_fragments` for concatenated arguments."
  @type meta :: %{required(:line) => pos_integer(), optional(:string_fragments) => [String.t()]}

  @typedoc "A source comment: `{line, text}`."
  @type comment :: {pos_integer(), String.t()}

  # Compile-time map from YANG keyword string → atom. Covers all RFC 7950
  # standard keywords. Using a map lookup bypasses String.to_existing_atom/1
  # entirely for known keywords, which avoids the atom-table timing problem
  # (to_existing_atom fails if the owning module hasn't been loaded yet).
  # Unknown tokens still go through to_existing_atom with a rescue fallback
  # so extension keywords that happen to be pre-defined atoms still convert,
  # while truly novel strings remain strings (no atom flooding from user input).
  @yang_keyword_map %{
    "module" => :module,
    "submodule" => :submodule,
    "namespace" => :namespace,
    "prefix" => :prefix,
    "organization" => :organization,
    "contact" => :contact,
    "description" => :description,
    "reference" => :reference,
    "revision" => :revision,
    "import" => :import,
    "include" => :include,
    "typedef" => :typedef,
    "type" => :type,
    "container" => :container,
    "leaf" => :leaf,
    "leaf-list" => :"leaf-list",
    "list" => :list,
    "choice" => :choice,
    "case" => :case,
    "anydata" => :anydata,
    "anyxml" => :anyxml,
    "grouping" => :grouping,
    "uses" => :uses,
    "rpc" => :rpc,
    "action" => :action,
    "input" => :input,
    "output" => :output,
    "notification" => :notification,
    "augment" => :augment,
    "deviation" => :deviation,
    "deviate" => :deviate,
    "identity" => :identity,
    "feature" => :feature,
    "if-feature" => :"if-feature",
    "refine" => :refine,
    "key" => :key,
    "unique" => :unique,
    "mandatory" => :mandatory,
    "default" => :default,
    "units" => :units,
    "status" => :status,
    "config" => :config,
    "presence" => :presence,
    "path" => :path,
    "base" => :base,
    "bit" => :bit,
    "enum" => :enum,
    "modifier" => :modifier,
    "ordered-by" => :"ordered-by",
    "max-elements" => :"max-elements",
    "min-elements" => :"min-elements",
    "error-message" => :"error-message",
    "error-app-tag" => :"error-app-tag",
    "revision-date" => :"revision-date",
    "belongs-to" => :"belongs-to",
    "yang-version" => :"yang-version",
    "argument" => :argument,
    "extension" => :extension,
    "length" => :length,
    "pattern" => :pattern,
    "range" => :range,
    "fraction-digits" => :"fraction-digits",
    "require-instance" => :"require-instance",
    "position" => :position,
    "value" => :value
  }

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
  @spec parse(String.t()) ::
          {:ok, [statement()], [comment()], MapSet.t(pos_integer())} | {:error, String.t()}
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
                {:error,
                 "expected ';' or '{' after argument, got #{bad_type} at line #{bad_meta.line}"}
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

  # Standard YANG keywords are converted to atoms via direct map lookup against
  # @yang_keyword_map, which embeds the string→atom mapping at compile time.
  # This avoids String.to_existing_atom/1 for known keywords entirely, sidestepping
  # the atom-table timing issue where the atom may not yet be registered if the
  # builder module hasn't been invoked in this VM instance. Unknown tokens fall
  # back to to_existing_atom with a rescue so any pre-defined atoms still convert,
  # while truly novel strings remain strings (no atom flooding from user input).
  # Prefixed extension keywords always remain as string tuples.
  defp to_keyword({prefix, name}) do
    {prefix, name}
  end

  defp to_keyword(name) when is_binary(name) do
    case Map.fetch(@yang_keyword_map, name) do
      {:ok, atom} ->
        atom

      :error ->
        try do
          String.to_existing_atom(name)
        rescue
          ArgumentError -> name
        end
    end
  end

  defp keyword_to_string({prefix, name}), do: prefix <> ":" <> name
  defp keyword_to_string(name) when is_binary(name), do: name
end
