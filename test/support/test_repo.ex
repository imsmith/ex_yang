defmodule ExYang.TestRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :ex_yang, adapter: Ecto.Adapters.SQLite3
end
