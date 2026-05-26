defmodule Faro.GameEngine.DeckTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.{Card, Deck}

  describe "new/0" do
    test "produces exactly 52 cards" do
      assert Deck.size(Deck.new()) == 52
    end

    test "contains every rank × suit combination exactly once" do
      deck = Deck.new()
      pairs = Enum.map(deck, &{&1.rank, &1.suit})
      expected = for suit <- Card.suits(), rank <- Card.ranks(), do: {rank, suit}
      assert Enum.sort(pairs) == Enum.sort(expected)
    end

    test "all cards have valid ranks" do
      assert Enum.all?(Deck.new(), &Card.valid_rank?(&1.rank))
    end

    test "all cards have valid suits" do
      valid_suits = Card.suits()
      assert Enum.all?(Deck.new(), &(&1.suit in valid_suits))
    end
  end

  describe "serialize/1" do
    test "returns 52 strings" do
      assert length(Deck.serialize(Deck.new())) == 52
    end

    test "all entries are non-empty strings" do
      assert Enum.all?(Deck.serialize(Deck.new()), &(is_binary(&1) and byte_size(&1) > 0))
    end

    test "all serialized cards are unique" do
      serialized = Deck.serialize(Deck.new())
      assert length(serialized) == length(Enum.uniq(serialized))
    end
  end

  property "new/0 always produces 52 unique cards" do
    check all(_ <- constant(:ok)) do
      deck = Deck.new()
      assert length(deck) == 52
      assert length(deck) == length(Enum.uniq(deck))
    end
  end
end
