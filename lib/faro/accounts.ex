defmodule Faro.Accounts do
  @moduledoc """
  Domain for user account management.

  Responsible for user registration, authentication, session management,
  and identity. Integrates with AshAuthentication for secure credential
  handling. All player identity is anchored here.
  """

  use Ash.Domain

  resources do
  end
end
