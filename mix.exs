defmodule ExYang.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/imsmith/ex_yang"

  def project do
    [
      app: :ex_yang,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "YANG (RFC 7950) parser, resolver, and data modeling library for Elixir",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      docs: docs(),
      dialyzer: [flags: [:no_opaque]],
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      licenses: ["AGPL-3.0-only"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "ExYang",
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17", optional: true},
      {:postgrex, "~> 0.19", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
