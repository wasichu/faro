defmodule Faro.GameEngine.CardTest do
  use ExUnit.Case, async: true

  alias Faro.GameEngine.Card

  describe "valid_rank?/1" do
    test "accepts 1 through 13" do
      Enum.each(1..13, fn r -> assert Card.valid_rank?(r) end)
    end

    test "rejects 0 and 14" do
      refute Card.valid_rank?(0)
      refute Card.valid_rank?(14)
    end

    test "rejects non-integers" do
      refute Card.valid_rank?(:ace)
      refute Card.valid_rank?("A")
    end
  end

  describe "serialize/1" do
    test "ace of spades" do
      assert Card.serialize(%Card{rank: 1, suit: :spades}) == "As"
    end

    test "jack of hearts" do
      assert Card.serialize(%Card{rank: 11, suit: :hearts}) == "Jh"
    end

    test "queen of diamonds" do
      assert Card.serialize(%Card{rank: 12, suit: :diamonds}) == "Qd"
    end

    test "king of clubs" do
      assert Card.serialize(%Card{rank: 13, suit: :clubs}) == "Kc"
    end

    test "numeric ranks" do
      assert Card.serialize(%Card{rank: 2, suit: :spades}) == "2s"
      assert Card.serialize(%Card{rank: 10, suit: :hearts}) == "10h"
    end
  end

  describe "suits/0 and ranks/0" do
    test "suits returns all four" do
      assert Card.suits() == [:spades, :hearts, :diamonds, :clubs]
    end

    test "ranks is 1..13" do
      assert Enum.to_list(Card.ranks()) == Enum.to_list(1..13)
    end
  end
end
