File.mkdir_p!("tmp")
ExYang.TestRepo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(ExYang.TestRepo, :manual)
ExUnit.start()
