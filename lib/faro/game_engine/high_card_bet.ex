defmodule Faro.GameEngine.HighCardBet do
  @moduledoc """
  A bet on the high-card space at the top of the Faro layout.

  The player wagers that the winner (second card dealt) will have a
  higher rank than the loser (first card dealt). No rank is specified —
  the bet is purely on relative ordering.

  The `copper?` flag inverts the bet: a coppered high-card bet wins when
  the loser rank is higher than the winner rank.

  Payouts (un-coppered):
  - Winner rank > loser rank → net `+amount` (`:win`).
  - Winner rank < loser rank → net `-amount` (`:loss`).
  - Winner rank == loser rank (doublet) → net `0` (`:push`).

  Boundary: pure data — no I/O, no process state.
  """

  @type t :: %__MODULE__{amount: pos_integer(), copper?: boolean()}

  defstruct [:amount, copper?: false]
end
