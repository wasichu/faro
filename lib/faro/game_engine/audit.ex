defmodule Faro.GameEngine.Audit do
  @moduledoc """
  Provably-fair audit transcript for a completed Faro round.

  The transcript contains everything needed to independently verify that
  a round was dealt correctly, without trusting the server:

  1. `server_commitment` — published before play (SHA-256 of server seed).
  2. `server_seed` — revealed after the round ends.
  3. `client_seed` — provided by the player before play.
  4. `nonce` — round counter (integer).
  5. `shuffled_deck` — the 52-card deck after applying the shuffle.
  6. `soda` — the burned first card.
  7. `turns` — ordered list of turn records (loser rank, winner rank,
     settlements).

  ## Verification

  `verify_full/1` checks:

  - SHA-256(`server_seed`) == `server_commitment`
  - HMAC-SHA256(server_seed, client_seed <> nonce) reproduces the same
    shuffle, i.e. `shuffled_deck` is authentic.
  - Each turn's loser and winner ranks match the corresponding positions
    in `shuffled_deck` (positions 2k-1 and 2k for 1-indexed turn k,
    since position 0 is the soda).

  `verify/1` performs only the commitment check (useful mid-round).

  Boundary: pure data assembly and verification — no I/O, no process
  state, no Ecto/Ash calls.
  """

  alias Faro.GameEngine.{Deck, Fairness, Round, Shuffle, Turn}

  @algorithm_version Fairness.algorithm_version()

  @type turn_record :: %{
          turn_number: pos_integer(),
          loser_rank: pos_integer(),
          winner_rank: pos_integer(),
          split?: boolean(),
          settlements: list()
        }

  @type t :: %__MODULE__{
          algorithm_version: String.t(),
          server_commitment: Fairness.commitment(),
          server_seed: Fairness.seed(),
          client_seed: Fairness.seed(),
          nonce: Fairness.nonce(),
          shuffled_deck: Deck.t(),
          soda: term(),
          turns: [turn_record()],
          verified?: boolean()
        }

  defstruct [
    :server_commitment,
    :server_seed,
    :client_seed,
    :nonce,
    :shuffled_deck,
    :soda,
    algorithm_version: @algorithm_version,
    turns: [],
    verified?: false
  ]

  @doc """
  Builds an audit transcript from a completed `Round` and the fairness
  parameters used to produce it.
  """
  @spec from_round(
          Round.t(),
          Fairness.commitment(),
          Fairness.seed(),
          Fairness.seed(),
          Fairness.nonce(),
          Deck.t()
        ) :: t()
  def from_round(%Round{} = round, commitment, server_seed, client_seed, nonce, shuffled_deck) do
    turns = Enum.map(round.turns, &turn_record/1)

    %__MODULE__{
      server_commitment: commitment,
      server_seed: server_seed,
      client_seed: client_seed,
      nonce: nonce,
      shuffled_deck: shuffled_deck,
      soda: round.soda,
      turns: turns
    }
  end

  @doc "Appends a turn record to an in-progress transcript."
  @spec append_turn(t(), pos_integer(), Turn.t(), list()) :: t()
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

  @doc "Verifies the server seed commitment only. Sets `verified?` accordingly."
  @spec verify(t()) :: t()
  def verify(%__MODULE__{server_commitment: commitment, server_seed: seed} = transcript) do
    %{transcript | verified?: Fairness.verify(commitment, seed)}
  end

  @doc """
  Performs full verification: commitment, shuffle reproduction, and
  per-turn card position checks. Sets `verified?` accordingly.
  """
  @spec verify_full(t()) :: t()
  def verify_full(%__MODULE__{} = transcript) do
    commitment_ok = Fairness.verify(transcript.server_commitment, transcript.server_seed)

    seed =
      Fairness.derive_shuffle_seed(
        transcript.server_seed,
        transcript.client_seed,
        transcript.nonce
      )

    reproduced = Shuffle.shuffle(Deck.new(), seed)
    deck_ok = reproduced == transcript.shuffled_deck

    soda_ok = transcript.soda == Enum.at(transcript.shuffled_deck, 0)
    cards_ok = verify_cards(transcript.turns, transcript.shuffled_deck)

    %{transcript | verified?: commitment_ok && deck_ok && soda_ok && cards_ok}
  end

  defp verify_cards(turns, deck) do
    Enum.all?(turns, fn %{turn_number: k, loser_rank: lr, winner_rank: wr} ->
      loser = Enum.at(deck, 2 * k - 1)
      winner = Enum.at(deck, 2 * k)
      loser != nil && winner != nil && loser.rank == lr && winner.rank == wr
    end)
  end

  defp turn_record(%Turn{} = turn) do
    %{
      turn_number: turn.index,
      loser_rank: turn.loser.rank,
      winner_rank: turn.winner.rank,
      split?: turn.split?,
      settlements: turn.settlements
    }
  end
end
