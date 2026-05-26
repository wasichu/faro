defmodule Faro.GameEngine.Deck do
  @moduledoc """
  Represents a standard 52-card Faro deck (4 suits × 13 ranks).

  In historical Faro, all four suits are present but only rank matters
  for resolving bets. The deck module produces an ordered deck and
  exposes operations needed by `Shuffle` and `Round`.

  Boundary: pure data transformation — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type t :: [Card.t()]

  @suits 1..4
  @ranks 1..13

  @doc "Returns a fresh, unshuffled 52-card deck."
  @spec new() :: t()
  def new do
    for _suit <- @suits, rank <- @ranks do
      %Card{rank: rank}
    end
  end

  @doc "Returns the number of cards remaining in the deck."
  @spec size(t()) :: non_neg_integer()
  def size(deck), do: length(deck)
end
