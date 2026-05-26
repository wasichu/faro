defmodule Faro.GameEngine.CasekeeperTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.{Card, Casekeeper, Turn}

  defp card(rank, suit \\ :spades), do: %Card{rank: rank, suit: suit}
  defp turn(loser_rank, winner_rank), do: Turn.new(1, card(loser_rank), card(winner_rank))

  describe "new/0" do
    test "all 13 ranks start at zero seen count" do
      ck = Casekeeper.new()
      Enum.each(1..13, fn rank -> assert Casekeeper.dealt(ck, rank) == 0 end)
    end

    test "all 13 ranks start with 4 remaining" do
      ck = Casekeeper.new()
      Enum.each(1..13, fn rank -> assert Casekeeper.remaining(ck, rank) == 4 end)
    end
  end

  describe "record_burned/2 (soda)" do
    test "decrements remaining for the burned rank by 1" do
      ck = Casekeeper.new() |> Casekeeper.record_burned(card(5))
      assert Casekeeper.remaining(ck, 5) == 3
      assert Casekeeper.dealt(ck, 5) == 1
    end

    test "does not affect other ranks" do
      ck = Casekeeper.new() |> Casekeeper.record_burned(card(5))

      Enum.each(1..13, fn rank ->
        if rank != 5 do
          assert Casekeeper.remaining(ck, rank) == 4
        end
      end)
    end

    test "stacks with subsequent turn records" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record_burned(card(5))
        |> Casekeeper.record(turn(5, 7))

      assert Casekeeper.remaining(ck, 5) == 2
      assert Casekeeper.dealt(ck, 5) == 2
    end
  end

  describe "record/2 and remaining/2" do
    test "decrements remaining for both loser and winner ranks" do
      ck = Casekeeper.new() |> Casekeeper.record(turn(3, 7))
      assert Casekeeper.remaining(ck, 3) == 3
      assert Casekeeper.remaining(ck, 7) == 3
      assert Casekeeper.remaining(ck, 5) == 4
    end

    test "split decrements remaining by 2 for the split rank" do
      ck = Casekeeper.new() |> Casekeeper.record(turn(5, 5))
      assert Casekeeper.remaining(ck, 5) == 2
    end

    test "accumulates correctly over multiple turns" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record(turn(1, 2))
        |> Casekeeper.record(turn(1, 3))
        |> Casekeeper.record(turn(1, 4))

      assert Casekeeper.remaining(ck, 1) == 1
      assert Casekeeper.dealt(ck, 1) == 3
    end
  end

  describe "dealt/2" do
    test "reflects cards seen including the burned soda" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record_burned(card(5))
        |> Casekeeper.record(turn(5, 7))
        |> Casekeeper.record(turn(5, 8))

      assert Casekeeper.dealt(ck, 5) == 3
      assert Casekeeper.dealt(ck, 7) == 1
      assert Casekeeper.dealt(ck, 9) == 0
    end
  end

  describe "last_turn_eligible?/2" do
    test "false when 4 remain" do
      refute Casekeeper.last_turn_eligible?(Casekeeper.new(), 3)
    end

    test "true when exactly 1 remains" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record(turn(3, 9))
        |> Casekeeper.record(turn(3, 10))
        |> Casekeeper.record(turn(3, 11))

      assert Casekeeper.last_turn_eligible?(ck, 3)
    end

    test "true when soda reduces count to 1 remaining" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record_burned(card(3))
        |> Casekeeper.record(turn(3, 9))
        |> Casekeeper.record(turn(3, 10))

      assert Casekeeper.last_turn_eligible?(ck, 3)
    end

    test "false when 0 remain" do
      ck =
        Casekeeper.new()
        |> Casekeeper.record(turn(3, 9))
        |> Casekeeper.record(turn(3, 10))
        |> Casekeeper.record(turn(3, 11))
        |> Casekeeper.record(turn(3, 12))

      refute Casekeeper.last_turn_eligible?(ck, 3)
    end
  end

  property "remaining + dealt always equals 4 for any rank" do
    check all(
            turns_count <- integer(0..3),
            rank <- integer(1..13)
          ) do
      ck =
        Enum.reduce(1..max(turns_count, 1), Casekeeper.new(), fn i, ck ->
          Casekeeper.record(ck, Turn.new(i, card(rank), card(rem(rank, 13) + 1)))
        end)

      assert Casekeeper.remaining(ck, rank) + Casekeeper.dealt(ck, rank) == 4
    end
  end

  property "record_burned counts toward remaining + dealt total" do
    check all(rank <- integer(1..13)) do
      ck = Casekeeper.new() |> Casekeeper.record_burned(card(rank))
      assert Casekeeper.remaining(ck, rank) + Casekeeper.dealt(ck, rank) == 4
      assert Casekeeper.remaining(ck, rank) == 3
    end
  end
end
