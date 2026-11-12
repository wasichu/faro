defmodule Faro.GameEngine.Wager do
  @moduledoc "Validation shared by engine callers and transcript verification."

  alias Faro.GameEngine.{Bet, CallTheTurnBet, Card, HighCardBet}

  @max_amount 9_223_372_036_854_775_807

  def valid?(%Bet{rank: rank, amount: amount, copper?: copper?}) do
    Card.valid_rank?(rank) and valid_amount?(amount) and is_boolean(copper?)
  end

  def valid?(%HighCardBet{amount: amount, copper?: copper?}) do
    valid_amount?(amount) and is_boolean(copper?)
  end

  def valid?(%CallTheTurnBet{predicted_loser: loser, predicted_winner: winner, amount: amount}) do
    Card.valid_rank?(loser) and Card.valid_rank?(winner) and valid_amount?(amount)
  end

  def valid?(_), do: false

  def valid_amount?(amount), do: is_integer(amount) and amount > 0 and amount <= @max_amount
end
