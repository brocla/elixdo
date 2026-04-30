Application.put_env(:elixdo, :clock, Elixdo.Clock.Mock)
Application.put_env(:elixdo, :ocr, Elixdo.OCR.Mock)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Elixdo.Repo, :manual)
