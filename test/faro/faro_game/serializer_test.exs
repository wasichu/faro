defmodule Faro.FaroGame.SerializerTest do
  use ExUnit.Case, async: true

  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Bet, CallTheTurnBet, Card, HighCardBet}

  describe "card round-trip" do
    test "encodes and decodes all four suits" do
      for suit <- [:spades, :hearts, :diamonds, :clubs] do
        card = %Card{rank: 7, suit: suit}
        assert Serializer.decode_card(Serializer.encode_card(card)) == card
      end
    end

    test "preserves all ranks 1..13" do
      for rank <- 1..13 do
        card = %Card{rank: rank, suit: :spades}
        assert Serializer.decode_card(Serializer.encode_card(card)) == card
      end
    end
  end

  describe "deck round-trip" do
    test "encodes and decodes a full 52-card deck" do
      alias Faro.GameEngine.Deck
      deck = Deck.new()
      assert Serializer.decode_deck(Serializer.encode_deck(deck)) == deck
    end
  end

  describe "bet round-trip" do
    test "rank bet" do
      bet = %Bet{rank: 10, amount: 5000, copper?: true}
      assert Serializer.decode_bet(Serializer.encode_bet(bet)) == bet
    end

    test "call the turn bet" do
      bet = %CallTheTurnBet{predicted_loser: 3, predicted_winner: 7, amount: 2000}
      assert Serializer.decode_bet(Serializer.encode_bet(bet)) == bet
    end

    test "high card bet" do
      bet = %HighCardBet{amount: 1500, copper?: false}
      assert Serializer.decode_bet(Serializer.encode_bet(bet)) == bet
    end
  end

  describe "settlement round-trip" do
    test "encodes win settlement" do
      bet = %Bet{rank: 5, amount: 1000, copper?: false}
      s = %{bet: bet, net: 1000, outcome: :win}
      encoded = Serializer.encode_settlement(s)
      assert encoded["outcome"] == "win"
      assert encoded["net"] == 1000
    end

    test "decodes settlement back to atoms" do
      bet = %Bet{rank: 5, amount: 1000, copper?: false}
      s = %{bet: bet, net: -1000, outcome: :loss}
      decoded = Serializer.decode_settlement(Serializer.encode_settlement(s))
      assert decoded.outcome == :loss
      assert decoded.net == -1000
      assert decoded.bet == bet
    end
  end
end
