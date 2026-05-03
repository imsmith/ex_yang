defmodule ExYangExtensionsOnRpcTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "rpc preserves prefixed extension uses in :extensions field" do
    src = """
    module t {
      yang-version 1.1;
      namespace "urn:t";
      prefix t;
      revision 2026-04-27 { description "x"; }
      rpc create-note {
        wagger-mcp:tool-name "create_note";
        wagger-mcp:dangerous;
        description "Save a note.";
      }
    }
    """

    assert {:ok, parsed} = ExYang.parse(src)
    [rpc] = parsed.rpcs
    assert length(rpc.extensions) == 2

    tool_name_ext = Enum.find(rpc.extensions, fn e -> e.keyword == {"wagger-mcp", "tool-name"} end)
    refute is_nil(tool_name_ext), "tool-name extension missing"
    assert tool_name_ext.argument == "create_note"

    dangerous_ext = Enum.find(rpc.extensions, fn e -> e.keyword == {"wagger-mcp", "dangerous"} end)
    refute is_nil(dangerous_ext), "dangerous extension missing"
  end
end
