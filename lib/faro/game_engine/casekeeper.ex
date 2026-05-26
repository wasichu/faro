defmodule Faro.GameEngine.Casekeeper do
  @moduledoc """
  Tracks which card ranks have been revealed during a round.

  In historical Faro, a physical casekeeper (an abacus-like device)
  recorded how many cards of each rank remained. Players used it to
  identify last-turn opportunities and inform betting strategy.

  Each rank starts with 4 copies in the 52-card deck. The soda (burned
  first card) is counted via `record_burned/2` before any turns so that
  `remaining/2` reflects the true count from the very first bet.

  A doublet (split) consumes 2 cards of the same rank in one turn,
  decrementing that rank's remaining count by 2.

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.{Card, Turn}

  @cards_per_rank 4

  @type counts :: %{Card.rank() => non_neg_integer()}
  @type t :: %__MODULE__{seen: counts()}

  defstruct seen: %{}

  @doc "Returns a fresh casekeeper with all 13 ranks at zero seen count."
  @spec new() :: t()
  def new do
    seen = for rank <- Card.ranks(), into: %{}, do: {rank, 0}
    %__MODULE__{seen: seen}
  end

  @doc """
  Records a single burned card (the soda) without associating it with a turn.

  The soda is removed from the deck at round start before any betting
  occurs. Counting it here keeps `remaining/2` accurate so players see
  3 remaining for the soda's rank from the very first turn.
  """
  @spec record_burned(t(), Card.t()) :: t()
  def record_burned(%__MODULE__{seen: seen} = casekeeper, %Card{rank: rank}) do
    %{casekeeper | seen: Map.update!(seen, rank, &(&1 + 1))}
  end

  @doc "Records the two cards revealed in a completed turn."
  @spec record(t(), Turn.t()) :: t()
  def record(%__MODULE__{seen: seen} = casekeeper, %Turn{loser: loser, winner: winner}) do
    seen =
      seen
      |> Map.update!(loser.rank, &(&1 + 1))
      |> Map.update!(winner.rank, &(&1 + 1))

    %{casekeeper | seen: seen}
  end

  @doc "Returns how many cards of `rank` remain in the deck (0–4)."
  @spec remaining(t(), Card.rank()) :: non_neg_integer()
  def remaining(%__MODULE__{seen: seen}, rank) do
    @cards_per_rank - Map.get(seen, rank, 0)
  end

  @doc "Returns how many cards of `rank` have been revealed so far (including soda)."
  @spec dealt(t(), Card.rank()) :: non_neg_integer()
  def dealt(%__MODULE__{seen: seen}, rank) do
    Map.get(seen, rank, 0)
  end

  @doc """
  Returns true if exactly one card of `rank` remains.

  A last-turn-eligible rank is guaranteed to appear in the next turn
  that deals it, which can inform call-the-turn predictions.
  """
  @spec last_turn_eligible?(t(), Card.rank()) :: boolean()
  def last_turn_eligible?(casekeeper, rank) do
    remaining(casekeeper, rank) == 1
  end
end
