defmodule Faro.Audit.Verification do
  @moduledoc "Verifies persisted turns using the same engine checks as completed transcripts."

  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Audit, Fairness}

  def verify(%{status: status}, _turns) when status != :finished do
    %{
      status: :incomplete,
      message: "The round has not finished. Its server seed is still hidden."
    }
  end

  def verify(%{server_seed: nil}, _turns) do
    %{status: :incomplete, message: "Server seed not yet revealed."}
  end

  def verify(round, turns) do
    deck = Serializer.decode_deck(round.shuffled_deck)

    transcript = %Audit{
      algorithm_version: round.algorithm_version,
      server_commitment: round.server_seed_hash,
      server_seed: round.server_seed,
      client_seed: round.client_seed,
      nonce: round.nonce,
      shuffled_deck: deck,
      soda: Serializer.decode_card(%{"rank" => round.soda_rank, "suit" => round.soda_suit}),
      turns: Enum.map(turns, &transcript_turn/1)
    }

    checks = Audit.checks(transcript)

    suits_ok =
      Enum.all?(turns, fn turn ->
        loser = Enum.at(deck, turn.index * 2 - 1)
        winner = Enum.at(deck, turn.index * 2)

        loser != nil and winner != nil and to_string(loser.suit) == turn.loser_suit and
          to_string(winner.suit) == turn.winner_suit
      end)

    checks = Map.update!(checks, :cards_ok, &(&1 and suits_ok))
    seed = Fairness.derive_shuffle_seed(round.server_seed, round.client_seed, round.nonce)

    Map.merge(checks, %{
      status: :complete,
      overall: Enum.all?(Map.values(checks)),
      deck: deck,
      shuffle_seed_hex: Base.encode16(seed, case: :lower)
    })
  rescue
    _error in [
      ArgumentError,
      FunctionClauseError,
      KeyError,
      BadMapError,
      ArithmeticError,
      Protocol.UndefinedError
    ] ->
      %{
        status: :invalid,
        overall: false,
        algorithm_ok: false,
        hash_ok: false,
        deck_ok: false,
        soda_ok: false,
        cards_ok: false,
        settlements_ok: false,
        deck: [],
        shuffle_seed_hex: ""
      }
  end

  defp transcript_turn(turn) do
    %{
      turn_number: turn.index,
      loser_rank: turn.loser_rank,
      winner_rank: turn.winner_rank,
      split?: turn.split,
      bets: Enum.map(turn.bets, &Serializer.decode_bet/1),
      settlements: Enum.map(turn.settlements, &Serializer.decode_settlement/1)
    }
  end
end
