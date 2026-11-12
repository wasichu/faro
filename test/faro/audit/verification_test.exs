defmodule Faro.Audit.VerificationTest do
  use ExUnit.Case, async: true

  alias Faro.Audit.Verification
  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Bet, Deck, Fairness, Round, Shuffle}

  defp persisted_round do
    seed = :binary.copy(<<42>>, 32)
    deck = Shuffle.shuffle(Deck.new(), Fairness.derive_shuffle_seed(seed, "client", 1))

    {round, turns} =
      Enum.reduce(1..25, {Round.new(deck), []}, fn _, {round, turns} ->
        bets = if round.phase == :dealing, do: [%Bet{rank: 1, amount: 100}], else: []
        {turn, next} = Round.deal_turn(round, bets)

        record = %{
          index: turn.index,
          loser_rank: turn.loser.rank,
          loser_suit: to_string(turn.loser.suit),
          winner_rank: turn.winner.rank,
          winner_suit: to_string(turn.winner.suit),
          split: turn.split?,
          bets: Enum.map(turn.bets, &Serializer.encode_bet/1),
          settlements: Enum.map(turn.settlements, &Serializer.encode_settlement/1)
        }

        {next, [record | turns]}
      end)

    db_round = %{
      status: :finished,
      server_seed: seed,
      server_seed_hash: Fairness.commit_server_seed(seed),
      algorithm_version: Fairness.algorithm_version(),
      client_seed: "client",
      nonce: 1,
      shuffled_deck: Serializer.encode_deck(deck),
      soda_rank: round.soda.rank,
      soda_suit: to_string(round.soda.suit)
    }

    {db_round, Enum.reverse(turns)}
  end

  test "stored verification requires complete sequential turns and exact suits and settlements" do
    {round, [first | rest] = turns} = persisted_round()
    assert Verification.verify(round, turns).overall

    for corrupted <- [
          rest,
          Enum.reverse(turns),
          [%{first | index: 2} | rest],
          [%{first | loser_suit: "bogus"} | rest],
          [%{first | settlements: []} | rest],
          [%{first | split: not first.split} | rest]
        ] do
      refute Verification.verify(round, corrupted).overall
    end

    refute Verification.verify(%{round | algorithm_version: "unknown"}, turns).overall

    refute Verification.verify(%{round | shuffled_deck: [%{"rank" => 1, "suit" => "nil"}]}, turns).overall
  end
end
