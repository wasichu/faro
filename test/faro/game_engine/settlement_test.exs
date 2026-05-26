defmodule Faro.GameEngine.SettlementTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.{Bet, CallTheTurnBet, Card, HighCardBet, Settlement, Turn}

  defp card(rank, suit \\ :spades), do: %Card{rank: rank, suit: suit}
  defp turn(loser_rank, winner_rank), do: Turn.new(1, card(loser_rank), card(winner_rank))
  defp bet(rank, amount, copper? \\ false), do: %Bet{rank: rank, amount: amount, copper?: copper?}

  defp ctt_bet(pl, pw, amount),
    do: %CallTheTurnBet{predicted_loser: pl, predicted_winner: pw, amount: amount}

  describe "settle/2 — standard outcomes" do
    test "win: bet rank matches winner" do
      [result] = Settlement.settle([bet(7, 100)], turn(3, 7))
      assert result.net == 100
      assert result.outcome == :win
    end

    test "loss: bet rank matches loser" do
      [result] = Settlement.settle([bet(3, 100)], turn(3, 7))
      assert result.net == -100
      assert result.outcome == :loss
    end

    test "push: bet rank on neither card" do
      [result] = Settlement.settle([bet(5, 100)], turn(3, 7))
      assert result.net == 0
      assert result.outcome == :push
    end

    test "split: both cards same rank, loses half" do
      [result] = Settlement.settle([bet(5, 100)], turn(5, 5))
      assert result.net == -50
      assert result.outcome == :split
    end

    test "split with odd amount rounds toward zero" do
      [result] = Settlement.settle([bet(5, 101)], turn(5, 5))
      assert result.net == -50
    end
  end

  describe "settle/2 — copper bets" do
    test "copper win: rank matches loser (inverted)" do
      [result] = Settlement.settle([bet(3, 100, true)], turn(3, 7))
      assert result.net == 100
      assert result.outcome == :win
    end

    test "copper loss: rank matches winner (inverted)" do
      [result] = Settlement.settle([bet(7, 100, true)], turn(3, 7))
      assert result.net == -100
      assert result.outcome == :loss
    end

    test "copper does not affect a split" do
      [result] = Settlement.settle([bet(5, 100, true)], turn(5, 5))
      assert result.net == -50
      assert result.outcome == :split
    end

    test "copper does not affect a push" do
      [result] = Settlement.settle([bet(9, 100, true)], turn(3, 7))
      assert result.net == 0
      assert result.outcome == :push
    end
  end

  describe "settle/2 — multiple bets" do
    test "settles all bets independently" do
      bets = [bet(7, 100), bet(3, 50), bet(5, 200)]
      results = Settlement.settle(bets, turn(3, 7))
      nets = Enum.map(results, & &1.net)
      assert nets == [100, -50, 0]
    end
  end

  describe "settle_call_the_turn/2" do
    test "void when all three cards are the same rank" do
      cards = [card(5), card(5, :hearts), card(5, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(5, 5, 100), cards)
      assert result.net == 0
      assert result.outcome == :void
    end

    test "cat-hop correct guess pays 1:1" do
      # ranks: [5, 5, 7] — two fives, one seven
      cards = [card(5), card(7, :hearts), card(5, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(5, 7, 100), cards)
      assert result.net == 100
      assert result.outcome == :win
    end

    test "cat-hop incorrect guess loses stake" do
      cards = [card(5), card(7, :hearts), card(5, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(7, 5, 100), cards)
      assert result.net == -100
      assert result.outcome == :loss
    end

    test "3 distinct ranks correct guess pays 4:1" do
      cards = [card(3), card(7, :hearts), card(11, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(3, 7, 100), cards)
      assert result.net == 400
      assert result.outcome == :win
    end

    test "3 distinct ranks incorrect guess loses stake" do
      cards = [card(3), card(7, :hearts), card(11, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(7, 3, 100), cards)
      assert result.net == -100
      assert result.outcome == :loss
    end
  end

  describe "settle_high_card/2" do
    test "win when winner rank is higher" do
      result = Settlement.settle_high_card(%HighCardBet{amount: 100}, turn(3, 9))
      assert result.net == 100
      assert result.outcome == :win
    end

    test "loss when winner rank is lower" do
      result = Settlement.settle_high_card(%HighCardBet{amount: 100}, turn(9, 3))
      assert result.net == -100
      assert result.outcome == :loss
    end

    test "push on a doublet" do
      result = Settlement.settle_high_card(%HighCardBet{amount: 100}, turn(7, 7))
      assert result.net == 0
      assert result.outcome == :push
    end
  end

  property "high card win always nets +amount" do
    check all(
            loser_rank <- integer(1..12),
            amount <- positive_integer()
          ) do
      winner_rank = loser_rank + 1

      result =
        Settlement.settle_high_card(%HighCardBet{amount: amount}, turn(loser_rank, winner_rank))

      assert result.net == amount
      assert result.outcome == :win
    end
  end

  property "high card loss always nets -amount" do
    check all(
            winner_rank <- integer(1..12),
            amount <- positive_integer()
          ) do
      loser_rank = winner_rank + 1

      result =
        Settlement.settle_high_card(%HighCardBet{amount: amount}, turn(loser_rank, winner_rank))

      assert result.net == -amount
      assert result.outcome == :loss
    end
  end

  property "standard win always nets +amount" do
    check all(
            rank <- integer(1..13),
            amount <- positive_integer()
          ) do
      other = if rank == 1, do: 2, else: 1
      [result] = Settlement.settle([bet(rank, amount)], turn(other, rank))
      assert result.net == amount
    end
  end

  property "standard loss always nets -amount" do
    check all(
            rank <- integer(1..13),
            amount <- positive_integer()
          ) do
      other = if rank == 1, do: 2, else: 1
      [result] = Settlement.settle([bet(rank, amount)], turn(rank, other))
      assert result.net == -amount
    end
  end

  property "split always nets -div(amount, 2)" do
    check all(
            rank <- integer(1..13),
            amount <- positive_integer()
          ) do
      [result] = Settlement.settle([bet(rank, amount)], turn(rank, rank))
      assert result.net == -div(amount, 2)
    end
  end

  property "copper inverts win to loss and vice versa" do
    check all(
            rank <- integer(1..13),
            amount <- positive_integer()
          ) do
      other = if rank == 1, do: 2, else: 1

      [win_result] = Settlement.settle([bet(rank, amount)], turn(other, rank))
      [cop_result] = Settlement.settle([bet(rank, amount, true)], turn(other, rank))

      assert win_result.net == amount
      assert cop_result.net == -amount
    end
  end

  property "call-the-turn correct 3-distinct pays 4x amount" do
    check all(
            rank_a <- integer(1..11),
            amount <- positive_integer()
          ) do
      rank_b = rank_a + 1
      rank_c = rank_a + 2
      cards = [card(rank_a), card(rank_b, :hearts), card(rank_c, :diamonds)]
      result = Settlement.settle_call_the_turn(ctt_bet(rank_a, rank_b, amount), cards)
      assert result.net == amount * 4
    end
  end
end
