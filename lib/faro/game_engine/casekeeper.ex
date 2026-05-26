defmodule Faro.GameEngine.Casekeeper do
  @moduledoc """
  Tracks which card ranks have been dealt during a round.

  In historical Faro, a casekeeper (also spelled case-keeper) is a
  physical abacus-like device that records how many cards of each rank
  remain in the deck. Players use this information to refine their
  betting strategy.

  Each rank starts with 4 cards in the deck. As turns are played, the
  casekeeper records how many of each rank have appeared. When only one
  card of a rank remains, it is said to be "last turn eligible."

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.{Card, Turn}

  @type counts :: %{Card.rank() => non_neg_integer()}
  @type t :: %__MODULE__{seen: counts()}

  defstruct seen: %{}

  @doc "Returns a fresh casekeeper with all ranks at zero seen count."
  @spec new() :: t()
  def new do
    seen = for rank <- 1..13, into: %{}, do: {rank, 0}
    %__MODULE__{seen: seen}
  end

  @doc "Records the loser and winner cards from a completed turn."
  @spec record(t(), Turn.t()) :: t()
  def record(%__MODULE__{seen: seen} = casekeeper, %Turn{loser: loser, winner: winner}) do
    seen =
      seen
      |> Map.update!(loser.rank, &(&1 + 1))
      |> Map.update!(winner.rank, &(&1 + 1))

    %{casekeeper | seen: seen}
  end

  @doc "Returns how many cards of `rank` remain in the deck (max 4)."
  @spec remaining(t(), Card.rank()) :: non_neg_integer()
  def remaining(%__MODULE__{seen: seen}, rank) do
    4 - Map.get(seen, rank, 0)
  end
end
