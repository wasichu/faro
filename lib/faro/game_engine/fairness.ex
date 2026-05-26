defmodule Faro.GameEngine.Fairness do
  @moduledoc """
  Provably-fair seed commitment and verification scheme.

  Protocol (per round):

  1. Server generates `server_seed` via `generate_server_seed/0`.
  2. Server publishes `commitment = SHA-256(server_seed)` before play.
  3. Player provides `client_seed` (any binary) and a `nonce` (integer,
     typically the round number).
  4. The shuffle seed is derived: `derive_shuffle_seed/3`.
  5. After the round, server reveals `server_seed`.
  6. Any observer can verify: `SHA-256(server_seed) == commitment`, then
     re-derive the shuffle seed and reproduce the full shuffle.

  The two-party seed scheme ensures neither party alone controls the
  shuffle outcome.

  Boundary: pure cryptographic functions — no I/O, no process state.
  """

  @algorithm_version "faro-shuffle-v1"

  @type seed :: binary()
  @type commitment :: String.t()
  @type nonce :: non_neg_integer()

  @doc "The shuffle algorithm identifier embedded in audit transcripts."
  @spec algorithm_version() :: String.t()
  def algorithm_version, do: @algorithm_version

  @doc "Generates a cryptographically random 32-byte server seed."
  @spec generate_server_seed() :: seed()
  def generate_server_seed do
    :crypto.strong_rand_bytes(32)
  end

  @doc "Produces a hex-encoded SHA-256 commitment for `server_seed`."
  @spec commit_server_seed(seed()) :: commitment()
  def commit_server_seed(server_seed) do
    :crypto.hash(:sha256, server_seed)
    |> Base.encode16(case: :lower)
  end

  @doc "Returns true if `commitment` matches SHA-256(`server_seed`)."
  @spec verify(commitment(), seed()) :: boolean()
  def verify(commitment, server_seed) do
    commit_server_seed(server_seed) == commitment
  end

  @doc """
  Derives a deterministic shuffle seed from the three inputs.

  Uses HMAC-SHA256 with `server_seed` as the key and
  `client_seed <> <<nonce::big-64>>` as the data, producing 32 bytes
  suitable for use with `Faro.GameEngine.Shuffle.shuffle/2`.
  """
  @spec derive_shuffle_seed(seed(), seed(), nonce()) :: binary()
  def derive_shuffle_seed(server_seed, client_seed, nonce) do
    data = client_seed <> <<nonce::big-64>>
    :crypto.mac(:hmac, :sha256, server_seed, data)
  end
end
