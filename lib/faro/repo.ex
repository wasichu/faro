defmodule Faro.Repo do
  use AshPostgres.Repo,
    otp_app: :faro

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
