defmodule Faro.GameEngine.RoundTest do
  use ExUnit.Case, async: true

  alias Faro.GameEngine.{Bet, CallTheTurnBet, Casekeeper, Deck, Fairness, Round, Shuffle}

  defp shuffled_deck do
    seed = Fairness.derive_shuffle_seed("server_seed", "client_seed", 1)
    Shuffle.shuffle(Deck.new(), seed)
  end

  describe "new/1" do
    test "burns the first card as the soda" do
      deck = shuffled_deck()
      round = Round.new(deck)
      assert round.soda == hd(deck)
    end

    test "remaining deck is 51 cards after soda burn" do
      round = Round.new(shuffled_deck())
      assert length(round.deck) == 51
    end

    test "starts in :dealing phase" do
      assert Round.phase(Round.new(shuffled_deck())) == :dealing
    end

    test "no turns played yet" do
      assert Round.new(shuffled_deck()).turns == []
    end

    test "casekeeper counts the soda rank as dealt" do
      deck = shuffled_deck()
      round = Round.new(deck)
      soda_rank = round.soda.rank
      assert Casekeeper.dealt(round.casekeeper, soda_rank) == 1
      assert Casekeeper.remaining(round.casekeeper, soda_rank) == 3
    end

    test "casekeeper shows 4 remaining for all other ranks" do
      deck = shuffled_deck()
      round = Round.new(deck)
      soda_rank = round.soda.rank

      Enum.each(1..13, fn rank ->
        if rank != soda_rank do
          assert Casekeeper.remaining(round.casekeeper, rank) == 4
        end
      end)
    end
  end

  describe "deal_turn/2" do
    test "returns a completed turn with the next two cards" do
      round = Round.new(shuffled_deck())
      [loser, winner | _] = round.deck
      {turn, _new_round} = Round.deal_turn(round, [])
      assert turn.loser == loser
      assert turn.winner == winner
    end

    test "decrements the deck by 2" do
      round = Round.new(shuffled_deck())
      before_size = length(round.deck)
      {_turn, new_round} = Round.deal_turn(round, [])
      assert length(new_round.deck) == before_size - 2
    end

    test "increments turns list" do
      round = Round.new(shuffled_deck())
      {_turn, r2} = Round.deal_turn(round, [])
      assert length(r2.turns) == 1
    end

    test "turn index is sequential" do
      round = Round.new(shuffled_deck())
      {t1, r2} = Round.deal_turn(round, [])
      {t2, _r3} = Round.deal_turn(r2, [])
      assert t1.index == 1
      assert t2.index == 2
    end

    test "bets and settlements are recorded on the turn" do
      round = Round.new(shuffled_deck())
      [loser | _] = round.deck
      bet = %Bet{rank: loser.rank, amount: 100}
      {turn, _} = Round.deal_turn(round, [bet])
      assert turn.bets == [bet]
      assert length(turn.settlements) == 1
    end

    test "call-the-turn bets during :dealing phase are voided" do
      round = Round.new(shuffled_deck())
      ctt_bet = %CallTheTurnBet{predicted_loser: 1, predicted_winner: 2, amount: 100}
      {turn, _} = Round.deal_turn(round, [ctt_bet])
      [settlement] = turn.settlements
      assert settlement.outcome == :void
      assert settlement.net == 0
    end

    test "raises when round is :finished" do
      round = Round.new(shuffled_deck())

      finished =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      assert Round.phase(finished) == :finished
      assert_raise ArgumentError, fn -> Round.deal_turn(finished, []) end
    end
  end

  describe "phase transitions" do
    test "transitions to :call_the_turn after 24 standard turns (3 cards remain)" do
      round = Round.new(shuffled_deck())

      # 51 cards → 24 turns × 2 = 48 dealt → 3 remain
      round =
        Enum.reduce(1..24, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      assert Round.phase(round) == :call_the_turn
      assert length(round.deck) == 3
    end

    test "transitions to :finished after the call-the-turn deal (25th total deal)" do
      round = Round.new(shuffled_deck())

      final =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      assert Round.phase(final) == :finished
    end

    test "hock card is accessible after finishing" do
      round = Round.new(shuffled_deck())

      finished =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      assert %Faro.GameEngine.Card{} = Round.hock(finished)
    end
  end

  describe "full round" do
    test "24 standard turns then 1 call-the-turn deal (25 total)" do
      round = Round.new(shuffled_deck())

      final =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      assert length(final.turns) == 25
    end

    test "soda + 50 dealt cards + 1 hock accounts for all 52" do
      deck = shuffled_deck()
      round = Round.new(deck)

      final =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      dealt_cards = Enum.flat_map(final.turns, &[&1.loser, &1.winner])
      all_accounted = [round.soda] ++ dealt_cards ++ [Round.hock(final)]

      assert length(all_accounted) == 52

      assert Enum.sort_by(all_accounted, &Faro.GameEngine.Card.serialize/1) ==
               Enum.sort_by(deck, &Faro.GameEngine.Card.serialize/1)
    end

    test "casekeeper after full round accounts for all 52 cards" do
      round = Round.new(shuffled_deck())

      final =
        Enum.reduce(1..25, round, fn _, r ->
          {_, r} = Round.deal_turn(r, [])
          r
        end)

      # 50 cards dealt across turns + 1 soda burned = 51 seen;
      # hock is NOT recorded in the casekeeper (never dealt)
      total_seen = Enum.sum(for rank <- 1..13, do: Casekeeper.dealt(final.casekeeper, rank))
      assert total_seen == 51
    end
  end
end
