defmodule Faro.GameEngine.Settlement do
  @moduledoc """
  Resolves bets against a completed turn or the final three cards.

  ## Standard bets (`settle/2`)

  Each `Bet` is checked against the turn's loser and winner ranks:

  - **Win**: the bet rank matches the winner → net `+amount`.
  - **Loss**: the bet rank matches the loser → net `-amount`.
  - **Split (doublet)**: both cards share the bet rank → net `-amount ÷ 2`
    (banker takes half; the remainder is returned). The copper flag does
    NOT invert a split — it always costs half.
  - **Push**: the bet rank appears on neither card → net `0`.

  The `copper?` flag inverts win and loss (but not split or push).

  ## Call-the-turn bets (`settle_call_the_turn/2`)

  Placed only when exactly three cards remain. Payout depends on how
  many of the three cards share the same rank:

  - **All same rank** (three of a kind remaining): bet is `:void` → net `0`
    (stake returned). No valid guess exists.
  - **Cat-hop** (exactly two cards share a rank): three possible
    (loser, winner) pairs. Correct guess → net `+amount` (1:1).
  - **Three distinct ranks**: six possible (loser, winner) pairs.
    Correct guess → net `+4 × amount` (4:1, historical house payout).
  - **Incorrect guess** (cat-hop or distinct): net `-amount`.

  All arithmetic uses integers to avoid floating-point rounding.

  Boundary: pure function — no I/O, no process state.
  """

  alias Faro.GameEngine.{Bet, CallTheTurnBet, HighCardBet, Turn, Card}

  @type outcome :: :win | :loss | :split | :push | :void
  @type result :: %{bet: Bet.t(), net: integer(), outcome: outcome()}
  @type ctt_result :: %{bet: CallTheTurnBet.t(), net: integer(), outcome: outcome()}
  @type high_card_result :: %{bet: HighCardBet.t(), net: integer(), outcome: outcome()}

  @doc "Resolves a list of standard bets against a completed turn."
  @spec settle_bets([Bet.t()], Turn.t()) :: [result()]
  def settle_bets(bets, turn) do
    Enum.map(bets, &settle_one(&1, turn))
  end

  @doc """
  Resolves a list of call-the-turn bets against the final three cards.

  `remaining` must be a list of exactly three `Card.t()` values in
  dealing order: `[loser, winner, hock]`.
  """
  @spec settle_call_the_turn_bets([CallTheTurnBet.t()], [Card.t()]) :: [ctt_result()]
  def settle_call_the_turn_bets(bets, remaining) do
    Enum.map(bets, &settle_call_the_turn(&1, remaining))
  end

  @doc """
  Resolves a single call-the-turn bet against the final three cards.

  See module doc for payout rules.
  """
  @spec settle_call_the_turn(CallTheTurnBet.t(), [Card.t()]) :: ctt_result()
  def settle_call_the_turn(%CallTheTurnBet{} = bet, [loser, winner, hock]) do
    ranks = Enum.map([loser, winner, hock], & &1.rank)
    distinct_count = ranks |> Enum.uniq() |> length()

    cond do
      distinct_count == 1 ->
        %{bet: bet, net: 0, outcome: :void}

      correct_call?(bet, loser, winner) && distinct_count == 2 ->
        %{bet: bet, net: bet.amount, outcome: :win}

      correct_call?(bet, loser, winner) && distinct_count == 3 ->
        %{bet: bet, net: bet.amount * 4, outcome: :win}

      true ->
        %{bet: bet, net: -bet.amount, outcome: :loss}
    end
  end

  @doc "Resolves a list of high-card bets against a completed turn."
  @spec settle_high_card_bets([HighCardBet.t()], Turn.t()) :: [high_card_result()]
  def settle_high_card_bets(bets, turn) do
    Enum.map(bets, &settle_high_card(&1, turn))
  end

  @doc """
  Resolves a single high-card bet against a completed turn.

  Winner rank > loser rank → `:win`. Winner rank < loser rank → `:loss`.
  Equal ranks (doublet) → `:push`.
  """
  @spec settle_high_card(HighCardBet.t(), Turn.t()) :: high_card_result()
  def settle_high_card(%HighCardBet{amount: amount} = bet, %Turn{loser: loser, winner: winner}) do
    {net, outcome} =
      cond do
        winner.rank > loser.rank -> {amount, :win}
        winner.rank < loser.rank -> {-amount, :loss}
        true -> {0, :push}
      end

    %{bet: bet, net: net, outcome: outcome}
  end

  defp correct_call?(%CallTheTurnBet{predicted_loser: pl, predicted_winner: pw}, loser, winner) do
    pl == loser.rank && pw == winner.rank
  end

  defp settle_one(%Bet{rank: rank, amount: amount, copper?: copper?} = bet, turn) do
    {net, outcome} = resolve(rank, amount, copper?, turn)
    %{bet: bet, net: net, outcome: outcome}
  end

  defp resolve(rank, amount, _copper?, %Turn{loser: %{rank: rank}, winner: %{rank: rank}}) do
    {-div(amount, 2), :split}
  end

  defp resolve(rank, amount, copper?, %Turn{loser: %{rank: rank}}) do
    if copper?, do: {amount, :win}, else: {-amount, :loss}
  end

  defp resolve(rank, amount, copper?, %Turn{winner: %{rank: rank}}) do
    if copper?, do: {-amount, :loss}, else: {amount, :win}
  end

  defp resolve(_rank, _amount, _copper?, _turn), do: {0, :push}
end
