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

  alias Faro.GameEngine.{Deck, Fairness, Round, Shuffle, Turn, Wager}

  @algorithm_version Fairness.algorithm_version()

  @type turn_record :: %{
          turn_number: pos_integer(),
          loser_rank: pos_integer(),
          winner_rank: pos_integer(),
          split?: boolean(),
          bets: list(),
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
      bets: turn.bets,
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
  all 25 sequential turns, split flags, wagers, and settlements. Sets `verified?` accordingly.
  """
  @spec verify_full(t()) :: t()
  def verify_full(%__MODULE__{} = transcript) do
    checks = checks(transcript)
    %{transcript | verified?: Enum.all?(Map.values(checks))}
  end

  @doc "Independent verification results, shared by the engine and persisted audit pages."
  def checks(%__MODULE__{} = transcript) do
    seed =
      Fairness.derive_shuffle_seed(
        transcript.server_seed,
        transcript.client_seed,
        transcript.nonce
      )

    reproduced = Shuffle.shuffle(Deck.new(), seed)
    {cards_ok, settlements_ok} = replay_checks(transcript.turns, reproduced)

    %{
      algorithm_ok: transcript.algorithm_version == @algorithm_version,
      hash_ok: Fairness.verify(transcript.server_commitment, transcript.server_seed),
      deck_ok: reproduced == transcript.shuffled_deck,
      soda_ok: transcript.soda == hd(reproduced),
      cards_ok: cards_ok,
      settlements_ok: settlements_ok
    }
  rescue
    _error in [ArgumentError, FunctionClauseError, KeyError, BadMapError, Protocol.UndefinedError] ->
      %{
        algorithm_ok: false,
        hash_ok: false,
        deck_ok: false,
        soda_ok: false,
        cards_ok: false,
        settlements_ok: false
      }
  end

  defp replay_checks(turns, deck) when is_list(turns) and length(turns) == 25 do
    {_, cards_ok, settlements_ok} =
      Enum.reduce(turns, {Round.new(deck), true, true}, fn record,
                                                           {round, cards_ok, settlements_ok} ->
        # Wagers must be independent of settlements: reconstructing them from
        # payouts would allow an omitted payout to erase its wager as well.
        bets = record.bets
        true = Enum.all?(bets, &Wager.valid?/1)
        {turn, next_round} = Round.deal_turn(round, bets)

        cards_match =
          record.turn_number == turn.index and
            record.loser_rank == turn.loser.rank and record.winner_rank == turn.winner.rank and
            record.split? == turn.split?

        {next_round, cards_ok and cards_match,
         settlements_ok and record.settlements == turn.settlements}
      end)

    {cards_ok, settlements_ok}
  rescue
    MatchError -> {false, false}
  end

  defp replay_checks(_turns, _deck), do: {false, false}

  defp turn_record(%Turn{} = turn) do
    %{
      turn_number: turn.index,
      loser_rank: turn.loser.rank,
      winner_rank: turn.winner.rank,
      split?: turn.split?,
      bets: turn.bets,
      settlements: turn.settlements
    }
  end
end
