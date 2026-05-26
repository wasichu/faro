defmodule Faro.GameEngine.Turn do
  @moduledoc """
  The complete record of a single Faro turn.

  A turn has four phases:

  1. **Betting** — players place `Bet` and/or `CallTheTurnBet` wagers.
  2. **Deal** — two cards are revealed from the dealing box: the loser
     (banker card) and the winner (player card).
  3. **Settlement** — each bet is resolved against the dealt cards.

  A doublet (split) occurs when both cards share the same rank; the
  banker takes half the stake on bets placed on that rank.

  The `Turn` struct is immutable. `Round.deal_turn/2` constructs
  completed turns; this module provides the constructor helpers.

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type t :: %__MODULE__{
          index: pos_integer(),
          loser: Card.t(),
          winner: Card.t(),
          split?: boolean(),
          bets: list(),
          settlements: list()
        }

  defstruct [:index, :loser, :winner, split?: false, bets: [], settlements: []]

  @doc "Constructs a turn record from its index and dealt cards."
  @spec new(pos_integer(), Card.t(), Card.t()) :: t()
  def new(index, %Card{rank: rank} = loser, %Card{rank: rank} = winner) do
    %__MODULE__{index: index, loser: loser, winner: winner, split?: true}
  end

  def new(index, loser, winner) do
    %__MODULE__{index: index, loser: loser, winner: winner, split?: false}
  end
end
