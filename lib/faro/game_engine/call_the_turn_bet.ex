defmodule Faro.GameEngine.CallTheTurnBet do
  @moduledoc """
  A call-the-turn bet placed when exactly three cards remain in the deck.

  The player predicts the exact ranks of the next loser (banker card) and
  winner (player card). The third remaining card is the hock, which is
  revealed after the deal but is not bet on directly.

  Payouts depend on how many distinct ranks are among the three
  remaining cards; see `Faro.GameEngine.Settlement.settle_call_the_turn/2`.

  Boundary: pure data — no I/O, no process state.
  """

  alias Faro.GameEngine.Card

  @type t :: %__MODULE__{
          predicted_loser: Card.rank(),
          predicted_winner: Card.rank(),
          amount: pos_integer()
        }

  defstruct [:predicted_loser, :predicted_winner, :amount]
end
