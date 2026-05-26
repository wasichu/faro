defmodule Faro.GameEngine.AuditTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.{Audit, Deck, Fairness, Round, Shuffle}

  defp build_transcript do
    server_seed = Fairness.generate_server_seed()
    client_seed = "player_client_seed"
    nonce = 42
    commitment = Fairness.commit_server_seed(server_seed)

    shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
    shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)

    round = Round.new(shuffled_deck)

    final_round =
      Enum.reduce(1..25, round, fn _, r ->
        {_, r} = Round.deal_turn(r, [])
        r
      end)

    Audit.from_round(final_round, commitment, server_seed, client_seed, nonce, shuffled_deck)
  end

  describe "from_round/6" do
    test "records 25 turn entries" do
      transcript = build_transcript()
      assert length(transcript.turns) == 25
    end

    test "records algorithm_version" do
      transcript = build_transcript()
      assert transcript.algorithm_version == "faro-shuffle-v1"
    end

    test "turn numbers are sequential starting from 1" do
      transcript = build_transcript()
      nums = Enum.map(transcript.turns, & &1.turn_number)
      assert nums == Enum.to_list(1..25)
    end

    test "captures all required fairness fields" do
      transcript = build_transcript()
      assert is_binary(transcript.server_commitment)
      assert is_binary(transcript.server_seed)
      assert transcript.client_seed == "player_client_seed"
      assert transcript.nonce == 42
      assert transcript.algorithm_version == "faro-shuffle-v1"
      assert length(transcript.shuffled_deck) == 52
      assert %Faro.GameEngine.Card{} = transcript.soda
    end

    test "records settlements on each turn entry" do
      server_seed = Fairness.generate_server_seed()
      client_seed = "cs"
      nonce = 1
      commitment = Fairness.commit_server_seed(server_seed)
      shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
      shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)
      round = Round.new(shuffled_deck)

      alias Faro.GameEngine.Bet
      [loser | _] = round.deck
      bet = %Bet{rank: loser.rank, amount: 100}

      {_, round_with_bet} = Round.deal_turn(round, [bet])

      final =
        Enum.reduce(1..24, round_with_bet, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      transcript =
        Audit.from_round(final, commitment, server_seed, client_seed, nonce, shuffled_deck)

      first_turn = hd(transcript.turns)
      assert length(first_turn.settlements) == 1
      assert hd(first_turn.settlements).outcome in [:win, :loss, :split, :push]
    end
  end

  describe "verify/1 — commitment check only" do
    test "marks verified? true with correct server_seed" do
      transcript = build_transcript()
      assert transcript.verified? == false
      result = Audit.verify(transcript)
      assert result.verified?
    end

    test "marks verified? false with tampered server_seed" do
      transcript = build_transcript()
      tampered = %{transcript | server_seed: :crypto.strong_rand_bytes(32)}
      result = Audit.verify(tampered)
      refute result.verified?
    end
  end

  describe "verify_full/1" do
    test "passes for an authentic transcript" do
      transcript = build_transcript()
      result = Audit.verify_full(transcript)
      assert result.verified?
    end

    test "fails when server_seed is tampered" do
      transcript = build_transcript()
      tampered = %{transcript | server_seed: :crypto.strong_rand_bytes(32)}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when shuffled_deck is tampered" do
      transcript = build_transcript()
      [first | rest] = transcript.shuffled_deck
      swapped = [%{first | rank: rem(first.rank, 13) + 1} | rest]
      tampered = %{transcript | shuffled_deck: swapped}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when soda is tampered" do
      transcript = build_transcript()
      soda = transcript.soda
      fake_soda = %{soda | rank: rem(soda.rank, 13) + 1}
      tampered = %{transcript | soda: fake_soda}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when a turn's loser_rank is tampered" do
      transcript = build_transcript()
      [turn | rest] = transcript.turns
      tampered_turn = %{turn | loser_rank: rem(turn.loser_rank, 13) + 1}
      tampered = %{transcript | turns: [tampered_turn | rest]}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when a turn's winner_rank is tampered" do
      transcript = build_transcript()
      [turn | rest] = transcript.turns
      tampered_turn = %{turn | winner_rank: rem(turn.winner_rank, 13) + 1}
      tampered = %{transcript | turns: [tampered_turn | rest]}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when client_seed is tampered" do
      transcript = build_transcript()
      tampered = %{transcript | client_seed: "tampered_client_seed"}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end

    test "fails when nonce is tampered" do
      transcript = build_transcript()
      tampered = %{transcript | nonce: transcript.nonce + 1}
      result = Audit.verify_full(tampered)
      refute result.verified?
    end
  end

  describe "append_turn/4" do
    test "adds turn records in order" do
      server_seed = Fairness.generate_server_seed()
      client_seed = "cs"
      nonce = 1
      commitment = Fairness.commit_server_seed(server_seed)

      shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
      shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)

      round = Round.new(shuffled_deck)
      {turn1, r2} = Round.deal_turn(round, [])
      {turn2, _r3} = Round.deal_turn(r2, [])

      transcript =
        %Audit{
          server_commitment: commitment,
          server_seed: server_seed,
          client_seed: client_seed,
          nonce: nonce,
          shuffled_deck: shuffled_deck,
          soda: round.soda
        }
        |> Audit.append_turn(1, turn1, turn1.settlements)
        |> Audit.append_turn(2, turn2, turn2.settlements)

      assert length(transcript.turns) == 2
      assert hd(transcript.turns).turn_number == 1
    end
  end

  property "verify_full passes for any valid transcript" do
    check all(
            server_seed <- binary(length: 32),
            client_seed <- binary(min_length: 1, max_length: 64),
            nonce <- non_negative_integer()
          ) do
      commitment = Fairness.commit_server_seed(server_seed)
      shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
      shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)

      round = Round.new(shuffled_deck)

      final_round =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      transcript =
        Audit.from_round(final_round, commitment, server_seed, client_seed, nonce, shuffled_deck)

      result = Audit.verify_full(transcript)
      assert result.verified?
    end
  end
end
