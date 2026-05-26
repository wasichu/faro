defmodule Faro.GameEngine.ShuffleTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.{Card, Deck, Shuffle}

  defp seed(str), do: :crypto.hash(:sha256, str)

  describe "shuffle/2" do
    test "returns a list of the same length as the input" do
      deck = Deck.new()
      shuffled = Shuffle.shuffle(deck, seed("test"))
      assert length(shuffled) == length(deck)
    end

    test "is deterministic for the same seed" do
      deck = Deck.new()
      s = seed("determinism")
      assert Shuffle.shuffle(deck, s) == Shuffle.shuffle(deck, s)
    end

    test "produces a different order with a different seed (probabilistic)" do
      deck = Deck.new()
      s1 = seed("seed_one")
      s2 = seed("seed_two")
      refute Shuffle.shuffle(deck, s1) == Shuffle.shuffle(deck, s2)
    end

    test "contains exactly the same cards as the original deck" do
      deck = Deck.new()
      shuffled = Shuffle.shuffle(deck, seed("any"))

      assert Enum.sort_by(shuffled, &Card.serialize/1) ==
               Enum.sort_by(deck, &Card.serialize/1)
    end

    test "changes output when nonce changes" do
      deck = Deck.new()
      srv = :crypto.strong_rand_bytes(32)
      cli = "player_seed"

      s1 = Faro.GameEngine.Fairness.derive_shuffle_seed(srv, cli, 1)
      s2 = Faro.GameEngine.Fairness.derive_shuffle_seed(srv, cli, 2)

      refute Shuffle.shuffle(deck, s1) == Shuffle.shuffle(deck, s2)
    end
  end

  property "shuffled deck is always a permutation of the original" do
    check all(seed_bytes <- binary(length: 32)) do
      deck = Deck.new()
      shuffled = Shuffle.shuffle(deck, seed_bytes)

      assert length(shuffled) == 52

      assert Enum.sort_by(shuffled, &Card.serialize/1) ==
               Enum.sort_by(deck, &Card.serialize/1)
    end
  end

  property "same seed always produces the same shuffle" do
    check all(seed_bytes <- binary(length: 32)) do
      deck = Deck.new()
      assert Shuffle.shuffle(deck, seed_bytes) == Shuffle.shuffle(deck, seed_bytes)
    end
  end
end
