defmodule Faro.GameEngine.Round do
  @moduledoc """
  Immutable state machine for a single Faro round.

  A round begins with a pre-shuffled 52-card deck. The first card is
  burned as the **soda** (no bets placed on it). The remaining 51 cards
  are dealt in pairs (loser, winner) across 25 turns. The 52nd card is
  the **hock** — revealed at the end of turn 25 but not dealt.

  ## Phases

  - `:dealing` — cards remain for one or more regular turns.
  - `:call_the_turn` — exactly 3 cards remain (loser, winner, hock).
    Players may place `CallTheTurnBet` wagers alongside regular bets.
  - `:finished` — the hock card alone remains; no more dealing.

  ## Immutability

  `deal_turn/2` returns both the completed `Turn` and a new `Round`
  value. No mutation occurs; callers chain calls on the returned round.

  Boundary: pure — delegates card logic to `Turn`, bets to `Settlement`,
  and tracking to `Casekeeper`. No I/O, no process state.
  """

  alias Faro.GameEngine.{Card, Casekeeper, CallTheTurnBet, HighCardBet, Settlement, Turn}

  @type phase :: :dealing | :call_the_turn | :finished

  @type t :: %__MODULE__{
          soda: Card.t(),
          deck: [Card.t()],
          turns: [Turn.t()],
          casekeeper: Casekeeper.t(),
          phase: phase()
        }

  defstruct [:soda, deck: [], turns: [], casekeeper: %Casekeeper{}, phase: :dealing]

  @doc """
  Starts a new round from a pre-shuffled 52-card deck.

  Burns the first card as the soda (no betting on the soda).
  """
  @spec new([Card.t()]) :: t()
  def new([soda | rest]) do
    casekeeper = Casekeeper.new() |> Casekeeper.record_burned(soda)

    %__MODULE__{
      soda: soda,
      deck: rest,
      turns: [],
      casekeeper: casekeeper,
      phase: detect_phase(length(rest))
    }
  end

  @doc """
  Deals the next turn, settling all provided bets.

  `bets` is a list of `Bet.t()`, `CallTheTurnBet.t()`, and/or `HighCardBet.t()`.
  Call-the-turn bets are only valid during the `:call_the_turn` phase; they
  are silently settled as void in other phases.

  Returns `{completed_turn, new_round}`.

  Raises if the round is already `:finished`.
  """
  @spec deal_turn(t(), list()) :: {Turn.t(), t()}
  def deal_turn(
        %__MODULE__{deck: [loser, winner | rest], turns: turns, casekeeper: ck, phase: phase} =
          round,
        bets
      ) do
    index = length(turns) + 1
    turn = Turn.new(index, loser, winner)

    all_settlements = settle_all(bets, turn, phase, [loser, winner | rest])
    completed_turn = %{turn | bets: bets, settlements: all_settlements}

    new_ck = Casekeeper.record(ck, turn)
    new_phase = detect_phase(length(rest))

    new_round = %{
      round
      | deck: rest,
        turns: turns ++ [completed_turn],
        casekeeper: new_ck,
        phase: new_phase
    }

    {completed_turn, new_round}
  end

  def deal_turn(%__MODULE__{phase: :finished}, _bets) do
    raise ArgumentError, "cannot deal from a finished round"
  end

  @doc "Returns the current phase of the round."
  @spec phase(t()) :: phase()
  def phase(%__MODULE__{phase: p}), do: p

  @doc "Returns the hock card (only available when round is :finished)."
  @spec hock(t()) :: Card.t() | nil
  def hock(%__MODULE__{phase: :finished, deck: [card]}), do: card
  def hock(%__MODULE__{}), do: nil

  defp settle_all(bets, turn, phase, remaining_cards) do
    {ctt_bets, rest} = Enum.split_with(bets, &match?(%CallTheTurnBet{}, &1))
    {hc_bets, std_bets} = Enum.split_with(rest, &match?(%HighCardBet{}, &1))

    ctt_results =
      if phase == :call_the_turn do
        Settlement.settle_call_the_turn_bets(ctt_bets, remaining_cards)
      else
        Enum.map(ctt_bets, &%{bet: &1, net: 0, outcome: :void})
      end

    Settlement.settle_bets(std_bets, turn) ++
      Settlement.settle_high_card_bets(hc_bets, turn) ++
      ctt_results
  end

  defp detect_phase(remaining) when remaining >= 4, do: :dealing
  defp detect_phase(3), do: :call_the_turn
  defp detect_phase(_), do: :finished
end
