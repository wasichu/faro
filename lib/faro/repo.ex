defmodule Faro.Repo do
  use Ecto.Repo,
    otp_app: :faro,
    adapter: Ecto.Adapters.Postgres
end
