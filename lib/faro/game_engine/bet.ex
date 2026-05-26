defmodule Faro.GameEngine.Bet do
  @moduledoc """
  A standard Faro bet placed on a card rank before a turn.

  A bet targets a specific rank and wagers an integer amount (token
  units). The `copper?` flag inverts the win/loss outcome — a coppered
  bet wins when the chosen rank is the losing card and loses when it is
  the winning card. Copper does not affect the split (doublet) half-loss
  rule, which always applies regardless.

  For the special last-turn bet, see `Faro.GameEngine.CallTheTurnBet`.

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
