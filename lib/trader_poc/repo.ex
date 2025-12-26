defmodule TraderPoc.Repo do
  use Ecto.Repo,
    otp_app: :trader_poc,
    adapter: Ecto.Adapters.Postgres
end
