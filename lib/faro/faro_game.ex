defmodule Faro.FaroGame do
  @moduledoc """
  Domain for Faro game persistence and lifecycle management.

  This is the persistence and coordination layer that sits between the
  pure `Faro.GameEngine` and the rest of the system. It stores game
  sessions, rounds, bets, and outcomes in the database, and translates
  engine results into ledger entries via `Faro.Wallets`.

  Architectural boundary: FaroGame calls into Faro.GameEngine for all
  game logic, but GameEngine never calls back into FaroGame.
  """

  use Ash.Domain

  resources do
  end
end
