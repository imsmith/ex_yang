defmodule ExYang.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :ex_yang,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: ["AGPL-3.0-only"],
      description: "YANG (RFC 7950) parser, resolver, and data modeling library for Elixir",
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ecto, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17", optional: true},
      {:postgrex, "~> 0.19", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
