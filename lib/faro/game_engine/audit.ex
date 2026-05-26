defmodule Faro.GameEngine.Audit do
  @moduledoc """
  Produces an auditable transcript of a completed Faro round.

  The audit transcript captures everything needed to independently
  verify that a round was dealt correctly:

    - The server seed commitment (pre-round).
    - The revealed server seed (post-round).
    - The client nonce.
    - The ordered sequence of cards dealt each turn.
    - The bets placed and their settlements.

  This is a pure data assembly module. It does not write to any store —
  the persistence layer (`Faro.Audit` domain) handles that.

  Boundary: pure data — no I/O, no process state, no Ecto/Ash calls.
  """

  alias Faro.GameEngine.{Fairness, Turn, Settlement}

  @type turn_record :: %{
          turn_number: pos_integer(),
          loser_rank: pos_integer(),
          winner_rank: pos_integer(),
          split?: boolean(),
          settlements: [Settlement.result()]
        }

  @type t :: %__MODULE__{
          server_commitment: Fairness.commitment(),
          server_seed: Fairness.seed(),
          client_nonce: Fairness.seed(),
          turns: [turn_record()],
          verified?: boolean()
        }

  defstruct [
    :server_commitment,
    :server_seed,
    :client_nonce,
    turns: [],
    verified?: false
  ]

  @doc "Verifies the transcript's seed commitment and marks it accordingly."
  @spec verify(t()) :: t()
  def verify(%__MODULE__{server_commitment: commitment, server_seed: seed} = transcript) do
    %{transcript | verified?: Fairness.verify(commitment, seed)}
  end

  @doc "Appends a completed turn and its settlements to the transcript."
  @spec append_turn(t(), pos_integer(), Turn.t(), [Settlement.result()]) :: t()
  def append_turn(%__MODULE__{turns: turns} = transcript, turn_number, turn, settlements) do
    record = %{
      turn_number: turn_number,
      loser_rank: turn.loser.rank,
      winner_rank: turn.winner.rank,
      split?: turn.split?,
      settlements: settlements
    }

    %{transcript | turns: turns ++ [record]}
  end
end
