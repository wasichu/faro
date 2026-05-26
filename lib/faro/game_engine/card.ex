defmodule Faro.GameEngine.Card do
  @moduledoc """
  Represents a single playing card.

  In Faro, suit is dealt (it appears on the physical card) but only rank
  determines bet resolution. Both fields are stored so audit transcripts
  can record the exact card dealt, enabling complete deck reproduction.

  Ranks: 1 = Ace, 11 = Jack, 12 = Queen, 13 = King.
  Suits: :spades, :hearts, :diamonds, :clubs.

  Boundary: pure data — no I/O, no process state, no persistence.
  """

  @type suit :: :spades | :hearts | :diamonds | :clubs
  @type rank :: 1..13
  @type t :: %__MODULE__{suit: suit(), rank: rank()}

  defstruct [:suit, :rank]

  @suits [:spades, :hearts, :diamonds, :clubs]
  @ranks 1..13

  @spec suits :: [suit()]
  def suits, do: @suits

  @spec ranks :: Enumerable.t()
  def ranks, do: @ranks

  @doc "Returns true if the given integer is a valid Faro card rank."
  def valid_rank?(rank) when rank in @ranks, do: true
  def valid_rank?(_), do: false

  @doc "Returns a short serialized string, e.g. \"As\", \"10h\", \"Kd\"."
  @spec serialize(t()) :: String.t()
  def serialize(%__MODULE__{rank: rank, suit: suit}) do
    rank_str(rank) <> suit_char(suit)
  end

  defp rank_str(1), do: "A"
  defp rank_str(11), do: "J"
  defp rank_str(12), do: "Q"
  defp rank_str(13), do: "K"
  defp rank_str(n), do: Integer.to_string(n)

  defp suit_char(:spades), do: "s"
  defp suit_char(:hearts), do: "h"
  defp suit_char(:diamonds), do: "d"
  defp suit_char(:clubs), do: "c"
end
