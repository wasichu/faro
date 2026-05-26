defmodule Faro.GameEngine.Shuffle do
  @moduledoc """
  Deterministic Fisher-Yates shuffle for a Faro deck.

  Algorithm: "faro-shuffle-v1"

  The PRNG uses HMAC-SHA256 in counter mode:

      random_bytes(counter) = HMAC-SHA256(key: seed, data: <<counter::big-64>>)

  Each 32-byte hash is interpreted as a big-endian unsigned integer and
  reduced modulo the current range to produce an index. The modulo bias
  is negligible (range ≤ 52, entropy = 2^256).

  Fisher-Yates (Knuth) runs from index n-1 down to 1, swapping each
  position with a randomly chosen position in [0, i]. This guarantees a
  uniform distribution over all n! permutations.

  Boundary: pure function — no I/O, no randomness source beyond `seed`.
  """

  alias Faro.GameEngine.{Deck, Fairness}

  @algorithm_version Fairness.algorithm_version()

  @doc "The shuffle algorithm identifier."
  @spec algorithm_version() :: String.t()
  def algorithm_version, do: @algorithm_version

  @doc """
  Shuffles `deck` deterministically using `seed` (a 32-byte binary).

  Calling with the same `deck` and `seed` always produces the same
  output. Use `Fairness.derive_shuffle_seed/3` to build the seed from
  the two-party commitment inputs.
  """
  @spec shuffle(Deck.t(), binary()) :: Deck.t()
  def shuffle(deck, seed) do
    arr = List.to_tuple(deck)
    n = tuple_size(arr)
    arr = fisher_yates(arr, n - 1, seed, 0)
    Tuple.to_list(arr)
  end

  defp fisher_yates(arr, 0, _seed, _counter), do: arr

  defp fisher_yates(arr, i, seed, counter) do
    j = random_int(seed, counter, i)
    arr = swap(arr, i, j)
    fisher_yates(arr, i - 1, seed, counter + 1)
  end

  defp random_int(seed, counter, max) do
    bytes = :crypto.mac(:hmac, :sha256, seed, <<counter::big-64>>)
    n = :binary.decode_unsigned(bytes)
    rem(n, max + 1)
  end

  defp swap(arr, i, j) do
    v_i = elem(arr, i)
    v_j = elem(arr, j)
    arr |> put_elem(i, v_j) |> put_elem(j, v_i)
  end
end
