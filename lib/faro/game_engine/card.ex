defmodule Faro.GameEngine.Card do
  @moduledoc """
  Represents a single playing card in the Faro game.

  A card is identified by its rank only — suit is irrelevant in Faro.
  Ranks run from Ace (1) through King (13). The card struct is the
  primitive value that flows through every other GameEngine module.

  Boundary: pure data — no I/O, no process state, no persistence.
  """

  @type rank :: 1..13
  @type t :: %__MODULE__{rank: rank()}

  defstruct [:rank]

  @ranks 1..13

  @doc "Returns true if the given integer is a valid Faro card rank."
  def valid_rank?(rank) when rank in @ranks, do: true
  def valid_rank?(_), do: false
end
