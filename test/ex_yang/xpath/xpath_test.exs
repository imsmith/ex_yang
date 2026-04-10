defmodule ExYang.XPathTest do
  @moduledoc false
  use ExUnit.Case, async: true

  doctest ExYang.XPath

  alias ExYang.XPath

  # ---------------------------------------------------------------------------
  # Path expressions
  # ---------------------------------------------------------------------------

  describe "path expressions" do
    test "absolute path" do
      assert {:ok, {:path, :absolute, [{:step, "interfaces"}, {:step, "interface"}]}} =
               XPath.parse("/interfaces/interface")
    end

    test "relative path" do
      assert {:ok, {:path, :relative, [{:step, ".."}, {:step, "type"}]}} =
               XPath.parse("../type")
    end

    test "relative path with single dot" do
      assert {:ok, {:path, :relative, [{:step, "."}, {:step, "name"}]}} =
               XPath.parse("./name")
    end

    test "prefixed name" do
      assert {:ok, {:path, :absolute, [{:step, {"if", "interfaces"}}, {:step, {"if", "interface"}}]}} =
               XPath.parse("/if:interfaces/if:interface")
    end

    test "current() path" do
      assert {:ok, {:path, :relative, [{:step, {:call, :current, []}}, {:step, ".."}, {:step, "type"}]}} =
               XPath.parse("current()/../type")
    end

    test "simple name path" do
      assert {:ok, {:path, :relative, [{:step, "enabled"}]}} =
               XPath.parse("enabled")
    end
  end

  # ---------------------------------------------------------------------------
  # Predicates
  # ---------------------------------------------------------------------------

  describe "predicates" do
    test "step with predicate" do
      assert {:ok,
              {:path, :relative,
               [{:step, "interface", {:eq, {:path, :relative, [{:step, "name"}]}, {:literal, "eth0"}}}]}} =
               XPath.parse("interface[name='eth0']")
    end

    test "absolute path with predicate" do
      assert {:ok,
              {:path, :absolute,
               [
                 {:step, "interfaces"},
                 {:step, "interface", {:eq, {:path, :relative, [{:step, "name"}]}, {:literal, "eth0"}}}
               ]}} =
               XPath.parse("/interfaces/interface[name='eth0']")
    end
  end

  # ---------------------------------------------------------------------------
  # Function calls
  # ---------------------------------------------------------------------------

  describe "function calls" do
    test "derived-from-or-self with two args" do
      assert {:ok, {:call, :"derived-from-or-self", [_path, {:literal, "ianaift:ethernetCsmacd"}]}} =
               XPath.parse("derived-from-or-self(type, 'ianaift:ethernetCsmacd')")
    end

    test "count with path argument" do
      assert {:ok, {:call, :count, [{:path, :relative, [{:step, ".."}, {:step, "interface"}]}]}} =
               XPath.parse("count(../interface)")
    end

    test "not with path argument" do
      assert {:ok, {:call, :not, [{:path, :relative, [{:step, ".."}, {:step, "disabled"}]}]}} =
               XPath.parse("not(../disabled)")
    end

    test "current() standalone" do
      assert {:ok, {:call, :current, []}} = XPath.parse("current()")
    end

    test "true() and false()" do
      assert {:ok, {:call, :true, []}} = XPath.parse("true()")
      assert {:ok, {:call, :false, []}} = XPath.parse("false()")
    end

    test "contains()" do
      assert {:ok, {:call, :contains, [{:path, :relative, [{:step, "name"}]}, {:literal, "eth"}]}} =
               XPath.parse("contains(name, 'eth')")
    end
  end

  # ---------------------------------------------------------------------------
  # Boolean expressions
  # ---------------------------------------------------------------------------

  describe "boolean expressions" do
    test "and expression" do
      assert {:ok,
              {:and,
               {:eq, {:path, :relative, [{:step, ".."}, {:step, "enabled"}]}, {:literal, "true"}},
               {:eq, {:path, :relative, [{:step, ".."}, {:step, "type"}]}, {:literal, "ethernet"}}}} =
               XPath.parse("../enabled = 'true' and ../type = 'ethernet'")
    end

    test "or expression" do
      assert {:ok,
              {:or,
               {:eq, {:path, :relative, [{:step, ".."}, {:step, "type"}]}, {:literal, "a"}},
               {:eq, {:path, :relative, [{:step, ".."}, {:step, "type"}]}, {:literal, "b"}}}} =
               XPath.parse("../type = 'a' or ../type = 'b'")
    end

    test "or does not match name starting with or" do
      # "order" should be parsed as a name, not "or" + "der"
      assert {:ok, {:path, :relative, [{:step, "order"}]}} = XPath.parse("order")
    end
  end

  # ---------------------------------------------------------------------------
  # Comparison expressions
  # ---------------------------------------------------------------------------

  describe "comparison expressions" do
    test "equals" do
      assert {:ok, {:eq, {:path, :relative, [{:step, "type"}]}, {:literal, "ethernet"}}} =
               XPath.parse("type = 'ethernet'")
    end

    test "not equals" do
      assert {:ok, {:neq, {:path, :relative, [{:step, "type"}]}, {:literal, "loopback"}}} =
               XPath.parse("type != 'loopback'")
    end

    test "less than" do
      assert {:ok, {:lt, {:path, :relative, [{:step, "mtu"}]}, {:number, "1500"}}} =
               XPath.parse("mtu < 1500")
    end

    test "greater than or equal" do
      assert {:ok, {:gte, {:path, :relative, [{:step, "speed"}]}, {:number, "1000"}}} =
               XPath.parse("speed >= 1000")
    end
  end

  # ---------------------------------------------------------------------------
  # Round-trip: parse -> format -> parse
  # ---------------------------------------------------------------------------

  describe "round-trip" do
    @roundtrip_cases [
      "/interfaces/interface",
      "../type",
      "current()/../type",
      "interface[name = 'eth0']",
      "count(../interface)",
      "not(../disabled)",
      "../enabled = 'true' and ../type = 'ethernet'",
      "../type = 'a' or ../type = 'b'",
      "type = 'ethernet'",
      "type != 'loopback'",
      "derived-from-or-self(type, 'ianaift:ethernetCsmacd')",
      "/if:interfaces/if:interface"
    ]

    for expr <- @roundtrip_cases do
      test "round-trip: #{expr}" do
        {:ok, ast} = XPath.parse(unquote(expr))
        formatted = XPath.format(ast)
        {:ok, ast2} = XPath.parse(formatted)
        assert ast == ast2
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Error cases
  # ---------------------------------------------------------------------------

  describe "error cases" do
    test "unterminated string" do
      assert {:error, _} = XPath.parse("name = 'unterminated")
    end

    test "empty input" do
      assert {:error, _} = XPath.parse("")
    end
  end
end
