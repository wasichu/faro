defmodule Faro.FaroGame do
  @moduledoc """
  Domain for Faro game persistence and lifecycle management.

  This is the persistence and coordination layer that sits between the
  pure `Faro.GameEngine` and the rest of the system. It stores game
  sessions, rounds, turns, and outcomes in the database.

  Architectural boundary: FaroGame calls into Faro.GameEngine for all
  game logic, but GameEngine never calls back into FaroGame.
  """

  use Ash.Domain

  resources do
    resource Faro.FaroGame.GameSession
    resource Faro.FaroGame.Round
    resource Faro.FaroGame.Turn
  end
end
