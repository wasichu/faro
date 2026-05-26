defmodule Faro.GameEngine.Fairness do
  @moduledoc """
  Provably-fair seed commitment and verification scheme.

  Before a round begins, the server commits to a SHA-256 hash of its
  seed. The player then provides a client nonce. After the round, the
  server reveals the pre-image. Any observer can verify:

    1. The server commitment matches SHA-256(server_seed).
    2. The combined seed (server_seed <> client_nonce) reproduces
       the shuffle recorded in the audit transcript.

  This module handles commitment generation and verification only.
  It never touches the deck or game state directly.

  Boundary: pure cryptographic functions — no I/O, no process state.
  """

  @type seed :: binary()
  @type commitment :: binary()

  @doc "Produces a SHA-256 commitment for a given server seed."
  @spec commit(seed()) :: commitment()
  def commit(server_seed) do
    :crypto.hash(:sha256, server_seed)
    |> Base.encode16(case: :lower)
  end

  @doc "Returns true if `commitment` matches SHA-256(server_seed)."
  @spec verify(commitment(), seed()) :: boolean()
  def verify(commitment, server_seed) do
    commit(server_seed) == commitment
  end

  @doc "Combines server seed and client nonce into the final shuffle seed."
  @spec combine(seed(), seed()) :: seed()
  def combine(server_seed, client_nonce) do
    server_seed <> client_nonce
  end
end
