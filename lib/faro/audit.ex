defmodule Faro.Audit do
  @moduledoc """
  Domain for provably-fair audit and verification.

  Stores the seed commitments, revealed seeds, shuffle proofs, and
  turn-by-turn game transcripts needed to independently verify that
  every round was dealt fairly. Consumers (players, third parties) can
  reconstruct and verify any historical hand without trusting the server.

  Architectural boundary: Audit records are written by FaroGame after
  each round completes. Audit never initiates game actions.
  """

  use Ash.Domain

  resources do
  end
end
