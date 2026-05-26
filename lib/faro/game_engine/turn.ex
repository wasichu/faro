defmodule Faro.GameEngine.Turn do
  @moduledoc """
  Represents the outcome of a single Faro turn (one deal of two cards).

  In Faro, each turn reveals two cards from the dealing box:
    - The soda (loser card) — bets on this rank lose.
    - The hock (winner card) — bets on this rank win.

  A split occurs when both cards share the same rank; the banker
  takes half the bet on that rank.

  Turn is a pure data structure. Bet resolution is delegated to
  `Settlement`.

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type t :: %__MODULE__{
          loser: Card.t(),
          winner: Card.t(),
          split?: boolean()
        }

  defstruct [:loser, :winner, split?: false]

  @doc "Builds a turn from the loser and winner cards dealt."
  @spec new(Card.t(), Card.t()) :: t()
  def new(%Card{rank: rank} = loser, %Card{rank: rank} = winner) do
    %__MODULE__{loser: loser, winner: winner, split?: true}
  end

  def new(loser, winner) do
    %__MODULE__{loser: loser, winner: winner, split?: false}
  end
end
