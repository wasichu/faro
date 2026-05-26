defmodule Faro.GameEngine.Deck do
  @moduledoc """
  Represents a standard 52-card Faro deck (4 suits × 13 ranks).

  `new/0` returns an ordered, unshuffled deck. The ordering is
  deterministic (suits outer, ranks inner) so audits can reproduce
  the pre-shuffle state from scratch without storing it.

  Boundary: pure data transformation — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type t :: [Card.t()]

  @doc "Returns a fresh, ordered, unshuffled 52-card deck."
  @spec new() :: t()
  def new do
    for suit <- Card.suits(), rank <- Card.ranks() do
      %Card{suit: suit, rank: rank}
    end
  end

  @doc "Returns the number of cards in the deck."
  @spec size(t()) :: non_neg_integer()
  def size(deck), do: length(deck)

  @doc "Returns a list of serialized card strings, e.g. [\"As\", \"2s\", ...]."
  @spec serialize(t()) :: [String.t()]
  def serialize(deck), do: Enum.map(deck, &Card.serialize/1)
end
