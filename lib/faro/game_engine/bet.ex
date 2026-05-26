defmodule Faro.GameEngine.Bet do
  @moduledoc """
  Represents a player's bet placed before a Faro turn.

  A bet targets a specific card rank and carries a wager amount. The
  `copper` flag inverts the bet — a coppered bet wins when the chosen
  rank is the loser card and loses when it is the winner card.

  Bets are immutable. `Settlement` takes a bet and a turn to produce
  a result.

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type amount :: pos_integer()

  @type t :: %__MODULE__{
          rank: Card.rank(),
          amount: amount(),
          copper?: boolean()
        }

  defstruct [:rank, :amount, copper?: false]
end
