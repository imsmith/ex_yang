defmodule ExYang.Diagnostic do
  @moduledoc """
  Structured diagnostic message emitted by parser, transform, validation,
  and resolution phases.
  """

  @enforce_keys [:severity, :phase, :message]
  defstruct [
    :severity,
    :phase,
    :message,
    :file,
    :line,
    :column,
    context: []
  ]

  @type severity :: :error | :warning | :info
  @type phase :: :lexer | :grammar | :transform | :validation | :resolution

  @type t :: %__MODULE__{
          severity: severity(),
          phase: phase(),
          message: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          context: [String.t()]
        }

  @doc "Format a diagnostic for terminal output."
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = d) do
    location =
      case {d.file, d.line, d.column} do
        {nil, nil, nil} -> ""
        {file, line, col} -> "\n  --> #{file || "<input>"}:#{line || "?"}:#{col || "?"}"
      end

    context =
      case d.context do
        [] -> ""
        parts -> "\n  in: #{Enum.join(parts, " > ")}"
      end

    "#{d.severity}[#{d.phase}]: #{d.message}#{location}#{context}"
  end
end
