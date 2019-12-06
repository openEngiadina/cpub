defmodule CPub.Repo do
  use Ecto.Repo,
    otp_app: :cpub,
    adapter: Ecto.Adapters.Postgres
end
