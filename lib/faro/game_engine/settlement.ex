defmodule Faro.GameEngine.Settlement do
  @moduledoc """
  Resolves bets against a completed turn to produce win/loss amounts.

  Settlement is the heart of Faro game logic. Given a list of bets and
  the turn result, it returns the net change in tokens for each bet:

    - Win:   player receives their wager back plus an equal profit.
    - Loss:  player loses their wager.
    - Split: banker takes half; player retains the other half (net: -wager/2).
    - Push:  no matching rank dealt — bet carries over (net: 0).

  All arithmetic uses integers (token units) to avoid floating-point
  rounding in financial calculations.

  Boundary: pure function — no I/O, no process state.
  """

  alias Faro.GameEngine.{Bet, Turn}

  @type result :: %{bet: Bet.t(), net: integer()}

  @doc """
  Resolves each bet in `bets` against `turn`, returning a list of
  `%{bet: bet, net: net_token_change}` maps.
  """
  @spec settle([Bet.t()], Turn.t()) :: [result()]
  def settle(bets, turn) do
    Enum.map(bets, &settle_one(&1, turn))
  end

  defp settle_one(%Bet{rank: rank, amount: amount, copper?: copper?} = bet, turn) do
    net = resolve(rank, amount, copper?, turn)
    %{bet: bet, net: net}
  end

  # Rank matches loser card
  defp resolve(rank, amount, copper?, %Turn{loser: %{rank: rank}, split?: false}) do
    if copper?, do: amount, else: -amount
  end

  # Rank matches winner card
  defp resolve(rank, amount, copper?, %Turn{winner: %{rank: rank}, split?: false}) do
    if copper?, do: -amount, else: amount
  end

  # Split: banker takes half
  defp resolve(rank, amount, _copper?, %Turn{loser: %{rank: rank}, split?: true}) do
    -div(amount, 2)
  end

  # No match: push
  defp resolve(_rank, _amount, _copper?, _turn), do: 0
end
