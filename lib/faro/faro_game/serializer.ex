defmodule Faro.FaroGame.Serializer do
  @moduledoc """
  Converts between `Faro.GameEngine` structs and plain maps for
  JSON storage in the persistence layer.

  GameEngine structs are not stored directly — they contain atoms and
  binary values that must be encoded to JSON-safe maps for JSONB columns.
  `encode_*` functions go from struct → map; `decode_*` go from map →
  struct (used when reconstructing engine state from the database).
  """

  alias Faro.GameEngine.{Bet, CallTheTurnBet, Card, HighCardBet}

  # ---------------------------------------------------------------------------
  # Card
  # ---------------------------------------------------------------------------

  @spec encode_card(Card.t()) :: map()
  def encode_card(%Card{rank: rank, suit: suit}),
    do: %{"rank" => rank, "suit" => to_string(suit)}

  @spec decode_card(map()) :: Card.t()
  def decode_card(%{"rank" => rank, "suit" => suit}),
    do: %Card{rank: rank, suit: String.to_existing_atom(suit)}

  # ---------------------------------------------------------------------------
  # Deck
  # ---------------------------------------------------------------------------

  @spec encode_deck([Card.t()]) :: [map()]
  def encode_deck(cards), do: Enum.map(cards, &encode_card/1)

  @spec decode_deck([map()]) :: [Card.t()]
  def decode_deck(maps), do: Enum.map(maps, &decode_card/1)

  # ---------------------------------------------------------------------------
  # Bets
  # ---------------------------------------------------------------------------

  @spec encode_bet(Bet.t() | CallTheTurnBet.t() | HighCardBet.t()) :: map()
  def encode_bet(%Bet{rank: rank, amount: amount, copper?: copper?}),
    do: %{"type" => "rank", "rank" => rank, "amount" => amount, "copper" => copper?}

  def encode_bet(%CallTheTurnBet{predicted_loser: loser, predicted_winner: winner, amount: amount}),
    do: %{
      "type" => "ctt",
      "predicted_loser" => loser,
      "predicted_winner" => winner,
      "amount" => amount
    }

  def encode_bet(%HighCardBet{amount: amount, copper?: copper?}),
    do: %{"type" => "high_card", "amount" => amount, "copper" => copper?}

  @spec decode_bet(map()) :: Bet.t() | CallTheTurnBet.t() | HighCardBet.t()
  def decode_bet(%{"type" => "rank", "rank" => rank, "amount" => amount, "copper" => copper?}),
    do: %Bet{rank: rank, amount: amount, copper?: copper?}

  def decode_bet(%{
        "type" => "ctt",
        "predicted_loser" => loser,
        "predicted_winner" => winner,
        "amount" => amount
      }),
      do: %CallTheTurnBet{predicted_loser: loser, predicted_winner: winner, amount: amount}

  def decode_bet(%{"type" => "high_card", "amount" => amount, "copper" => copper?}),
    do: %HighCardBet{amount: amount, copper?: copper?}

  # ---------------------------------------------------------------------------
  # Settlements
  # ---------------------------------------------------------------------------

  @spec encode_settlement(map()) :: map()
  def encode_settlement(%{bet: bet, net: net, outcome: outcome}),
    do: %{"bet" => encode_bet(bet), "net" => net, "outcome" => to_string(outcome)}

  @spec decode_settlement(map()) :: map()
  def decode_settlement(%{"bet" => bet_map, "net" => net, "outcome" => outcome}),
    do: %{bet: decode_bet(bet_map), net: net, outcome: String.to_existing_atom(outcome)}

  # ---------------------------------------------------------------------------
  # Audit turn records (from GameEngine.Audit.turn_record)
  # ---------------------------------------------------------------------------

  @spec encode_audit_turn(map()) :: map()
  def encode_audit_turn(%{
        turn_number: n,
        loser_rank: lr,
        winner_rank: wr,
        split?: split?,
        settlements: settlements
      }),
      do: %{
        "turn_number" => n,
        "loser_rank" => lr,
        "winner_rank" => wr,
        "split" => split?,
        "settlements" => Enum.map(settlements, &encode_settlement/1)
      }

  @spec decode_audit_turn(map()) :: map()
  def decode_audit_turn(%{
        "turn_number" => n,
        "loser_rank" => lr,
        "winner_rank" => wr,
        "split" => split?,
        "settlements" => settlements
      }),
      do: %{
        turn_number: n,
        loser_rank: lr,
        winner_rank: wr,
        split?: split?,
        settlements: Enum.map(settlements, &decode_settlement/1)
      }
end
