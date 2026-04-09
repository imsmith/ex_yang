import Config

config :ex_yang, ExYang.TestRepo,
  database: "tmp/test.sqlite3",
  pool: Ecto.Adapters.SQL.Sandbox
