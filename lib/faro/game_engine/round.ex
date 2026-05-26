defmodule Faro.GameEngine.Round do
  @moduledoc """
  Represents the state of a single Faro round (one dealing cycle).

  A round begins with a shuffled deck, progresses through a sequence of
  turns (each dealing two cards — a loser and a winner), and ends when
  the deck is exhausted. The casekeeper tracks which ranks have been
  seen.

  The round struct is an immutable value: each turn produces a new
  round struct. No mutation, no process state.

  Boundary: pure data — delegates turn mechanics to `Turn` and
  casekeeper tracking to `Casekeeper`.
  """

  alias Faro.GameEngine.Deck

  @type t :: %__MODULE__{
          deck: Deck.t(),
          turns_played: non_neg_integer(),
          finished?: boolean()
        }

  defstruct deck: [], turns_played: 0, finished?: false

  @doc "Creates a new round from a pre-shuffled deck."
  @spec new(Deck.t()) :: t()
  def new(deck) do
    %__MODULE__{deck: deck}
  end
end
