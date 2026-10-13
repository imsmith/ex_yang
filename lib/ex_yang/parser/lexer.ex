defmodule ExYang.Parser.Lexer do
  @moduledoc """
  NimbleParsec-based lexer for YANG (RFC 7950) source text.

  Produces a flat list of tokens, each shaped as:

      {type, %{line: n, column: n, offset: n}, value}

  Token types: `:keyword`, `:dq_string`, `:sq_string`, `:open_brace`,
  `:close_brace`, `:semicolon`, `:plus`, `:line_comment`, `:block_comment`,
  `:newline`, `:whitespace`.
  """

  import NimbleParsec

  @type token_type ::
          :keyword
          | :dq_string
          | :sq_string
          | :open_brace
          | :close_brace
          | :semicolon
          | :plus
          | :line_comment
          | :block_comment
          | :newline
          | :whitespace

  @typedoc "Source position of a token."
  @type position :: %{line: pos_integer(), column: pos_integer(), offset: non_neg_integer()}

  @typedoc "A token: `{type, position, value}`. Prefixed keywords carry a `{prefix, name}` value."
  @type token :: {token_type(), position(), String.t() | {String.t(), String.t()}}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Horizontal whitespace (spaces / tabs but NOT newlines)
  ws = ascii_string([?\s, ?\t], min: 1) |> tag(:whitespace)

  # Newlines — each newline is its own token so we can count lines
  newline =
    choice([
      string("\r\n"),
      string("\n"),
      string("\r")
    ])
    |> tag(:newline)

  # Punctuation
  open_brace = string("{") |> tag(:open_brace)
  close_brace = string("}") |> tag(:close_brace)
  semicolon = string(";") |> tag(:semicolon)
  plus = string("+") |> tag(:plus)

  # Line comment: // to end of line (don't consume the newline)
  line_comment =
    ignore(string("//"))
    |> utf8_string([not: ?\n, not: ?\r], min: 0)
    |> tag(:line_comment)

  # Block comment: /* ... */
  block_comment =
    ignore(string("/*"))
    |> repeat(
      lookahead_not(string("*/"))
      |> utf8_char([])
    )
    |> ignore(string("*/"))
    |> tag(:block_comment)

  # Double-quoted string with escape sequences
  dq_escape =
    ignore(ascii_char([?\\]))
    |> choice([
      ascii_char([?n]) |> replace(?\n),
      ascii_char([?t]) |> replace(?\t),
      ascii_char([?\\]) |> replace(?\\),
      ascii_char([?"]) |> replace(?")
    ])

  dq_string =
    ignore(ascii_char([?"]))
    |> repeat(
      choice([
        dq_escape,
        utf8_char(not: ?", not: ?\\)
      ])
    )
    |> ignore(ascii_char([?"]))
    |> tag(:dq_string)

  # Single-quoted string — literal, no escapes
  sq_string =
    ignore(ascii_char([?']))
    |> repeat(utf8_char(not: ?'))
    |> ignore(ascii_char([?']))
    |> tag(:sq_string)

  # Keyword / unquoted identifier
  # Start: [a-zA-Z_0-9]
  # Continue: [a-zA-Z0-9_.\-]
  # May contain a single colon separating prefix:name
  keyword_chars =
    utf8_char([?a..?z, ?A..?Z, ?0..?9, ?_])
    |> repeat(utf8_char([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?-]))

  prefixed_keyword =
    keyword_chars
    |> tag(:prefix)
    |> ignore(ascii_char([?:]))
    |> concat(keyword_chars |> tag(:name))
    |> tag(:prefixed_keyword)

  plain_keyword =
    keyword_chars
    |> tag(:keyword)

  keyword =
    choice([
      prefixed_keyword,
      plain_keyword
    ])

  # Top-level token
  token =
    choice([
      block_comment,
      line_comment,
      newline,
      ws,
      dq_string,
      sq_string,
      open_brace,
      close_brace,
      semicolon,
      plus,
      keyword
    ])

  defparsecp(:yang_tokens, repeat(token) |> eos(), inline: true)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Tokenize a YANG source string into a list of tokens.

  Returns `{:ok, tokens}` or `{:error, reason}`.
  """
  @spec tokenize(String.t()) :: {:ok, [token()]} | {:error, String.t()}
  def tokenize(input) do
    case yang_tokens(input) do
      {:ok, raw, "", _context, _line, _offset} ->
        {:ok, build_tokens(raw, input)}

      {:ok, _raw, rest, _context, {line, _}, offset} ->
        {:error,
         "unexpected input at line #{line}, offset #{offset}: #{inspect(String.slice(rest, 0, 20))}"}

      {:error, reason, _rest, _context, {line, _}, offset} ->
        {:error, "parse error at line #{line}, offset #{offset}: #{reason}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Token building — walk the raw tagged output and compute positions
  # ---------------------------------------------------------------------------

  defp build_tokens(raw_tags, input) do
    {tokens, _pos} = build_tokens_acc(raw_tags, {1, 1, 0}, input, [])
    Enum.reverse(tokens)
  end

  defp build_tokens_acc([], pos, _input, acc), do: {acc, pos}

  defp build_tokens_acc([{:newline, [text]} | rest], {line, _col, offset}, input, acc) do
    len = byte_size(text)
    meta = %{line: line, column: 1, offset: offset}
    token = {:newline, meta, text}
    build_tokens_acc(rest, {line + 1, 1, offset + len}, input, [token | acc])
  end

  defp build_tokens_acc([{:whitespace, [text]} | rest], {line, col, offset}, input, acc) do
    len = byte_size(text)
    meta = %{line: line, column: col, offset: offset}
    token = {:whitespace, meta, text}
    build_tokens_acc(rest, {line, col + len, offset + len}, input, [token | acc])
  end

  defp build_tokens_acc([{:open_brace, [_]} | rest], {line, col, offset}, input, acc) do
    meta = %{line: line, column: col, offset: offset}
    token = {:open_brace, meta, "{"}
    build_tokens_acc(rest, {line, col + 1, offset + 1}, input, [token | acc])
  end

  defp build_tokens_acc([{:close_brace, [_]} | rest], {line, col, offset}, input, acc) do
    meta = %{line: line, column: col, offset: offset}
    token = {:close_brace, meta, "}"}
    build_tokens_acc(rest, {line, col + 1, offset + 1}, input, [token | acc])
  end

  defp build_tokens_acc([{:semicolon, [_]} | rest], {line, col, offset}, input, acc) do
    meta = %{line: line, column: col, offset: offset}
    token = {:semicolon, meta, ";"}
    build_tokens_acc(rest, {line, col + 1, offset + 1}, input, [token | acc])
  end

  defp build_tokens_acc([{:plus, [_]} | rest], {line, col, offset}, input, acc) do
    meta = %{line: line, column: col, offset: offset}
    token = {:plus, meta, "+"}
    build_tokens_acc(rest, {line, col + 1, offset + 1}, input, [token | acc])
  end

  defp build_tokens_acc([{:line_comment, [text]} | rest], {line, col, offset}, input, acc) do
    # The original text in source is "//" + text
    source_len = 2 + byte_size(text)
    meta = %{line: line, column: col, offset: offset}
    token = {:line_comment, meta, text}
    build_tokens_acc(rest, {line, col + source_len, offset + source_len}, input, [token | acc])
  end

  defp build_tokens_acc([{:block_comment, chars} | rest], {line, col, offset}, input, acc) do
    text = List.to_string(chars)
    # Source is "/*" + text + "*/"
    source_len = 4 + byte_size(text)
    meta = %{line: line, column: col, offset: offset}
    token = {:block_comment, meta, text}

    # Count newlines inside the block comment to update position
    {new_line, new_col} = advance_through_text("/*" <> text <> "*/", line, col)

    build_tokens_acc(rest, {new_line, new_col, offset + source_len}, input, [token | acc])
  end

  defp build_tokens_acc([{:dq_string, chars} | rest], {line, col, offset}, input, acc) do
    value = List.to_string(chars)
    meta = %{line: line, column: col, offset: offset}
    token = {:dq_string, meta, value}

    # We need the original source length. Find the closing quote in input.
    source_text = extract_dq_source(input, offset)
    source_len = byte_size(source_text)
    {new_line, new_col} = advance_through_text(source_text, line, col)

    build_tokens_acc(rest, {new_line, new_col, offset + source_len}, input, [token | acc])
  end

  defp build_tokens_acc([{:sq_string, chars} | rest], {line, col, offset}, input, acc) do
    value = List.to_string(chars)
    meta = %{line: line, column: col, offset: offset}
    token = {:sq_string, meta, value}

    # source is  '  + value + '
    source_len = 2 + byte_size(value)
    source_text = binary_part(input, offset, source_len)
    {new_line, new_col} = advance_through_text(source_text, line, col)

    build_tokens_acc(rest, {new_line, new_col, offset + source_len}, input, [token | acc])
  end

  defp build_tokens_acc([{:prefixed_keyword, parts} | rest], {line, col, offset}, input, acc) do
    {:prefix, prefix_chars} = List.keyfind(parts, :prefix, 0)
    {:name, name_chars} = List.keyfind(parts, :name, 0)
    prefix = List.to_string(prefix_chars)
    name = List.to_string(name_chars)
    source_len = byte_size(prefix) + 1 + byte_size(name)
    meta = %{line: line, column: col, offset: offset}
    token = {:keyword, meta, {prefix, name}}
    build_tokens_acc(rest, {line, col + source_len, offset + source_len}, input, [token | acc])
  end

  defp build_tokens_acc([{:keyword, chars} | rest], {line, col, offset}, input, acc) do
    text = List.to_string(chars)
    len = byte_size(text)
    meta = %{line: line, column: col, offset: offset}
    token = {:keyword, meta, text}
    build_tokens_acc(rest, {line, col + len, offset + len}, input, [token | acc])
  end

  # Extract the double-quoted string source from input at offset (including quotes)
  defp extract_dq_source(input, offset) do
    rest = binary_part(input, offset, byte_size(input) - offset)
    # rest starts with "
    extract_dq_source_scan(rest, 1, false)
  end

  defp extract_dq_source_scan(input, pos, true) do
    # previous char was backslash, skip this char
    extract_dq_source_scan(input, pos + 1, false)
  end

  defp extract_dq_source_scan(input, pos, false) do
    case binary_part(input, pos, 1) do
      "\\" -> extract_dq_source_scan(input, pos + 1, true)
      "\"" -> binary_part(input, 0, pos + 1)
      _ -> extract_dq_source_scan(input, pos + 1, false)
    end
  end

  # Advance line/col through arbitrary text
  defp advance_through_text(text, line, col) do
    text
    |> String.to_charlist()
    |> Enum.reduce({line, col}, fn
      ?\n, {l, _c} -> {l + 1, 1}
      # \r alone resets col; \r\n handled by \n following
      ?\r, {l, _c} -> {l, 1}
      _, {l, c} -> {l, c + 1}
    end)
  end
end
