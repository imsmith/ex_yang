defmodule ExYang.XPath do
  @moduledoc """
  Hand-rolled recursive descent parser for the XPath 1.0 subset used in YANG
  `when` and `must` statements. Parses to an AST for inspection and formats
  ASTs back to strings. Does NOT evaluate.
  """

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec parse(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse(input) when is_binary(input) do
    tokens = tokenize(String.trim(input))

    case tokens do
      {:error, msg} -> {:error, msg}
      toks ->
        case parse_or_expr(toks) do
          {:ok, ast, []} -> {:ok, ast}
          {:ok, _ast, rest} -> {:error, "unexpected trailing tokens: #{inspect(rest)}"}
          {:error, _} = err -> err
        end
    end
  end

  @spec format(term()) :: String.t()
  def format(ast), do: do_format(ast)

  # ---------------------------------------------------------------------------
  # Tokenizer
  # ---------------------------------------------------------------------------

  @name_chars ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.:"

  defp tokenize(input), do: tokenize(input, [])

  defp tokenize(<<>>, acc), do: Enum.reverse(acc)

  defp tokenize(<<c, rest::binary>>, acc) when c in ~c" \t\n\r",
    do: tokenize(rest, acc)

  defp tokenize(<<"!=", rest::binary>>, acc), do: tokenize(rest, [:neq | acc])
  defp tokenize(<<"<=", rest::binary>>, acc), do: tokenize(rest, [:lte | acc])
  defp tokenize(<<">=", rest::binary>>, acc), do: tokenize(rest, [:gte | acc])
  defp tokenize(<<"=", rest::binary>>, acc), do: tokenize(rest, [:eq | acc])
  defp tokenize(<<"<", rest::binary>>, acc), do: tokenize(rest, [:lt | acc])
  defp tokenize(<<">", rest::binary>>, acc), do: tokenize(rest, [:gt | acc])
  defp tokenize(<<"(", rest::binary>>, acc), do: tokenize(rest, [:lparen | acc])
  defp tokenize(<<")", rest::binary>>, acc), do: tokenize(rest, [:rparen | acc])
  defp tokenize(<<"[", rest::binary>>, acc), do: tokenize(rest, [:lbracket | acc])
  defp tokenize(<<"]", rest::binary>>, acc), do: tokenize(rest, [:rbracket | acc])
  defp tokenize(<<",", rest::binary>>, acc), do: tokenize(rest, [:comma | acc])
  defp tokenize(<<"/", rest::binary>>, acc), do: tokenize(rest, [:slash | acc])
  defp tokenize(<<"+", rest::binary>>, acc), do: tokenize(rest, [:plus | acc])
  defp tokenize(<<"-", rest::binary>>, acc), do: tokenize(rest, [:minus | acc])

  defp tokenize(<<"'", rest::binary>>, acc) do
    case consume_until(rest, ?') do
      {:ok, str, rest2} -> tokenize(rest2, [{:string, str} | acc])
      :error -> {:error, "unterminated single-quoted string"}
    end
  end

  defp tokenize(<<"\"", rest::binary>>, acc) do
    case consume_until(rest, ?") do
      {:ok, str, rest2} -> tokenize(rest2, [{:dstring, str} | acc])
      :error -> {:error, "unterminated double-quoted string"}
    end
  end

  defp tokenize(<<c, _::binary>> = input, acc) when c in ?0..?9 do
    {num, rest} = consume_number(input)
    tokenize(rest, [{:number, num} | acc])
  end

  defp tokenize(<<c, _::binary>> = input, acc) when c in ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_" do
    {name, rest} = consume_name(input)
    tokenize(rest, [{:name, name} | acc])
  end

  # Allow .. and . as name tokens
  defp tokenize(<<"..", rest::binary>>, acc), do: tokenize(rest, [{:name, ".."} | acc])
  defp tokenize(<<".", rest::binary>>, acc), do: tokenize(rest, [{:name, "."} | acc])

  defp tokenize(<<c, _::binary>>, _acc), do: {:error, "unexpected character: #{<<c>>}"}

  defp consume_until(input, delim), do: consume_until(input, delim, [])

  defp consume_until(<<>>, _delim, _acc), do: :error

  defp consume_until(<<c, rest::binary>>, c, acc),
    do: {:ok, IO.iodata_to_binary(Enum.reverse(acc)), rest}

  defp consume_until(<<c, rest::binary>>, delim, acc),
    do: consume_until(rest, delim, [c | acc])

  defp consume_name(input), do: consume_name(input, [])

  defp consume_name(<<c, rest::binary>>, acc) when c in @name_chars,
    do: consume_name(rest, [c | acc])

  defp consume_name(rest, acc),
    do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

  defp consume_number(input), do: consume_number(input, [])

  defp consume_number(<<c, rest::binary>>, acc) when c in ?0..?9,
    do: consume_number(rest, [c | acc])

  defp consume_number(<<".", c, rest::binary>>, acc) when c in ?0..?9,
    do: consume_number(rest, [c, ?. | acc])

  defp consume_number(rest, acc),
    do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

  # ---------------------------------------------------------------------------
  # Parser — recursive descent
  # ---------------------------------------------------------------------------

  # or_expr = and_expr ('or' and_expr)*
  defp parse_or_expr(tokens) do
    with {:ok, left, rest} <- parse_and_expr(tokens) do
      parse_or_expr_tail(left, rest)
    end
  end

  defp parse_or_expr_tail(left, [{:name, "or"} = _tok | rest] = tokens) do
    # "or" is only the operator if the next token exists and "or" is not part
    # of a longer name (already handled by tokenizer — each name is a separate token).
    # But we still need to make sure "or" isn't actually a path step followed by
    # something that looks like and_expr. The tokenizer splits on whitespace, so
    # {:name, "or"} is always a standalone token. We treat it as the operator.
    case parse_and_expr(rest) do
      {:ok, right, rest2} ->
        parse_or_expr_tail({:or, left, right}, rest2)

      {:error, _} ->
        # Not actually an operator — treat as path continuation? Shouldn't happen
        # with well-formed input but be safe.
        {:ok, left, tokens}
    end
  end

  defp parse_or_expr_tail(left, tokens), do: {:ok, left, tokens}

  # and_expr = comparison ('and' comparison)*
  defp parse_and_expr(tokens) do
    with {:ok, left, rest} <- parse_comparison(tokens) do
      parse_and_expr_tail(left, rest)
    end
  end

  defp parse_and_expr_tail(left, [{:name, "and"} | rest]) do
    case parse_comparison(rest) do
      {:ok, right, rest2} ->
        parse_and_expr_tail({:and, left, right}, rest2)

      {:error, _} ->
        {:ok, left, [{:name, "and"} | rest]}
    end
  end

  defp parse_and_expr_tail(left, tokens), do: {:ok, left, tokens}

  # comparison = additive (comp_op additive)?
  defp parse_comparison(tokens) do
    with {:ok, left, rest} <- parse_additive(tokens) do
      case rest do
        [:eq | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:eq, left, right}, rest3}
        [:neq | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:neq, left, right}, rest3}
        [:lt | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:lt, left, right}, rest3}
        [:gt | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:gt, left, right}, rest3}
        [:lte | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:lte, left, right}, rest3}
        [:gte | rest2] -> with {:ok, right, rest3} <- parse_additive(rest2), do: {:ok, {:gte, left, right}, rest3}
        _ -> {:ok, left, rest}
      end
    end
  end

  # additive = primary (('+' | '-') primary)*
  defp parse_additive(tokens) do
    with {:ok, left, rest} <- parse_primary(tokens) do
      parse_additive_tail(left, rest)
    end
  end

  defp parse_additive_tail(left, [:plus | rest]) do
    with {:ok, right, rest2} <- parse_primary(rest) do
      parse_additive_tail({:add, left, right}, rest2)
    end
  end

  defp parse_additive_tail(left, [:minus | rest]) do
    with {:ok, right, rest2} <- parse_primary(rest) do
      parse_additive_tail({:sub, left, right}, rest2)
    end
  end

  defp parse_additive_tail(left, tokens), do: {:ok, left, tokens}

  # primary = literal | function_call | path | '(' or_expr ')'
  defp parse_primary(tokens) do
    case tokens do
      # Parenthesized expression
      [:lparen | rest] ->
        with {:ok, expr, rest2} <- parse_or_expr(rest) do
          case rest2 do
            [:rparen | rest3] -> {:ok, expr, rest3}
            _ -> {:error, "expected closing parenthesis"}
          end
        end

      # String literal
      [{:string, val} | rest] ->
        {:ok, {:literal, val}, rest}

      [{:dstring, val} | rest] ->
        {:ok, {:literal, val}, rest}

      # Number
      [{:number, val} | rest] ->
        {:ok, {:number, val}, rest}

      # Absolute path
      [:slash | _rest] ->
        parse_path(tokens)

      # Name — could be function call or path
      [{:name, _} | _] ->
        parse_name_or_path(tokens)

      [] ->
        {:error, "unexpected end of input"}

      [tok | _] ->
        {:error, "unexpected token: #{inspect(tok)}"}
    end
  end

  # A name token: could start a function call or a path
  defp parse_name_or_path([{:name, name} | [:lparen | _] = rest]) do
    # function call
    parse_function_call(name, rest)
  end

  defp parse_name_or_path(tokens) do
    parse_path(tokens)
  end

  # function_call = name '(' args ')'
  # After parsing, if followed by '/' it becomes part of a path
  defp parse_function_call(name, [:lparen | rest]) do
    {args, rest2} = parse_args(rest)

    case rest2 do
      [:rparen | rest3] ->
        call = {:call, String.to_atom(name), args}

        # Check if the call continues as a path: current()/..
        case rest3 do
          [:slash | _] ->
            # Re-wrap as a path with call as the first step
            parse_path_continuation(call, rest3)

          _ ->
            {:ok, call, rest3}
        end

      _ ->
        {:error, "expected closing parenthesis for function call #{name}()"}
    end
  end

  defp parse_args([:rparen | _] = tokens), do: {[], tokens}

  defp parse_args(tokens) do
    case parse_or_expr(tokens) do
      {:ok, arg, rest} ->
        case rest do
          [:comma | rest2] ->
            {more_args, rest3} = parse_args(rest2)
            {[arg | more_args], rest3}

          _ ->
            {[arg], rest}
        end

      {:error, _} ->
        {[], tokens}
    end
  end

  # Path continuation after a function call: call / step / step ...
  defp parse_path_continuation(call, [:slash | rest]) do
    case parse_steps(rest) do
      {:ok, steps, rest2} ->
        {:ok, {:path, :relative, [{:step, call} | steps]}, rest2}

      {:error, _} = err ->
        err
    end
  end

  # Parse a path (absolute or relative)
  defp parse_path([:slash | rest]) do
    case parse_steps(rest) do
      {:ok, steps, rest2} -> {:ok, {:path, :absolute, steps}, rest2}
      {:error, _} = err -> err
    end
  end

  defp parse_path(tokens) do
    case parse_steps(tokens) do
      {:ok, steps, rest} -> {:ok, {:path, :relative, steps}, rest}
      {:error, _} = err -> err
    end
  end

  # Parse one or more steps separated by /
  defp parse_steps(tokens) do
    case parse_step(tokens) do
      {:ok, step, rest} ->
        parse_more_steps([step], rest)

      {:error, _} = err ->
        err
    end
  end

  defp parse_more_steps(acc, [:slash | rest]) do
    case parse_step(rest) do
      {:ok, step, rest2} -> parse_more_steps(acc ++ [step], rest2)
      {:error, _} -> {:ok, Enum.reverse(Enum.reverse(acc)), [:slash | rest]}
    end
  end

  defp parse_more_steps(acc, tokens), do: {:ok, acc, tokens}

  # Parse a single step, optionally with predicates
  defp parse_step([{:name, _name}, :lparen | _] = tokens) do
    # Function call as a step (e.g., current())
    [{:name, fname} | rest] = tokens
    case parse_function_call(fname, rest) do
      {:ok, {:call, _, _} = call, rest2} ->
        # Check for predicate
        maybe_parse_predicate({:step, call}, rest2)

      {:ok, {:path, _, _} = path, rest2} ->
        # Function call expanded into a path — return as-is
        {:ok, path, rest2}

      err ->
        err
    end
  end

  defp parse_step([{:name, name} | rest]) do
    step = make_step(name)
    maybe_parse_predicate(step, rest)
  end

  defp parse_step(_tokens), do: {:error, "expected path step"}

  defp make_step(name) do
    case String.split(name, ":", parts: 2) do
      [prefix, local] when prefix != "" and local != "" ->
        {:step, {prefix, local}}

      _ ->
        {:step, name}
    end
  end

  defp maybe_parse_predicate(step, [:lbracket | rest]) do
    case parse_or_expr(rest) do
      {:ok, pred, [:rbracket | rest2]} ->
        step_with_pred =
          case step do
            {:step, name} -> {:step, name, pred}
            {:step, name, _} -> {:step, name, pred}
          end

        # Could have multiple predicates — check for another [
        maybe_parse_predicate(step_with_pred, rest2)

      {:ok, _, _} ->
        {:error, "expected closing bracket for predicate"}

      {:error, _} = err ->
        err
    end
  end

  defp maybe_parse_predicate(step, tokens), do: {:ok, step, tokens}

  # Handle function call that returned a path through parse_step
  # This shouldn't recurse into path again; handled inline above.

  # ---------------------------------------------------------------------------
  # Formatter
  # ---------------------------------------------------------------------------

  defp do_format({:path, :absolute, steps}) do
    "/" <> format_steps(steps)
  end

  defp do_format({:path, :relative, steps}) do
    format_steps(steps)
  end

  defp do_format({:step, {:call, _, _} = call}) do
    do_format(call)
  end

  defp do_format({:step, {prefix, local}}) do
    "#{prefix}:#{local}"
  end

  defp do_format({:step, name}) do
    name
  end

  defp do_format({:step, name, pred}) do
    base =
      case name do
        {:call, _, _} -> do_format(name)
        {prefix, local} -> "#{prefix}:#{local}"
        _ -> name
      end

    "#{base}[#{do_format(pred)}]"
  end

  defp do_format({:call, name, args}) do
    args_str = Enum.map_join(args, ", ", &do_format/1)
    "#{name}(#{args_str})"
  end

  defp do_format({:literal, val}) do
    "'#{val}'"
  end

  defp do_format({:number, val}) do
    val
  end

  defp do_format({:eq, left, right}) do
    "#{do_format(left)} = #{do_format(right)}"
  end

  defp do_format({:neq, left, right}) do
    "#{do_format(left)} != #{do_format(right)}"
  end

  defp do_format({:lt, left, right}) do
    "#{do_format(left)} < #{do_format(right)}"
  end

  defp do_format({:gt, left, right}) do
    "#{do_format(left)} > #{do_format(right)}"
  end

  defp do_format({:lte, left, right}) do
    "#{do_format(left)} <= #{do_format(right)}"
  end

  defp do_format({:gte, left, right}) do
    "#{do_format(left)} >= #{do_format(right)}"
  end

  defp do_format({:and, left, right}) do
    "#{do_format(left)} and #{do_format(right)}"
  end

  defp do_format({:or, left, right}) do
    "#{do_format(left)} or #{do_format(right)}"
  end

  defp do_format({:add, left, right}) do
    "#{do_format(left)} + #{do_format(right)}"
  end

  defp do_format({:sub, left, right}) do
    "#{do_format(left)} - #{do_format(right)}"
  end

  defp format_steps(steps) do
    Enum.map_join(steps, "/", &do_format/1)
  end
end
