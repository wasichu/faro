defmodule Faro.GameEngine.FairnessTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Faro.GameEngine.Fairness

  describe "generate_server_seed/0" do
    test "returns a 32-byte binary" do
      seed = Fairness.generate_server_seed()
      assert is_binary(seed)
      assert byte_size(seed) == 32
    end

    test "successive calls produce different seeds" do
      seeds = for _ <- 1..10, do: Fairness.generate_server_seed()
      assert length(Enum.uniq(seeds)) == 10
    end
  end

  describe "commit_server_seed/1" do
    test "returns a 64-character hex string" do
      commitment = Fairness.commit_server_seed("test_seed")
      assert is_binary(commitment)
      assert byte_size(commitment) == 64
      assert commitment =~ ~r/\A[0-9a-f]{64}\z/
    end

    test "is deterministic for the same seed" do
      c1 = Fairness.commit_server_seed("same")
      c2 = Fairness.commit_server_seed("same")
      assert c1 == c2
    end

    test "differs for different seeds" do
      assert Fairness.commit_server_seed("seed_a") != Fairness.commit_server_seed("seed_b")
    end
  end

  describe "verify/2" do
    test "returns true when commitment matches seed" do
      seed = "my secret seed"
      commitment = Fairness.commit_server_seed(seed)
      assert Fairness.verify(commitment, seed)
    end

    test "returns false when seed is tampered" do
      commitment = Fairness.commit_server_seed("real seed")
      refute Fairness.verify(commitment, "tampered seed")
    end

    test "returns false when commitment is tampered" do
      seed = "real seed"
      tampered = String.replace(Fairness.commit_server_seed(seed), "a", "b")
      refute Fairness.verify(tampered, seed)
    end
  end

  describe "derive_shuffle_seed/3" do
    test "returns 32 bytes" do
      seed = Fairness.derive_shuffle_seed("server", "client", 1)
      assert byte_size(seed) == 32
    end

    test "is deterministic" do
      s1 = Fairness.derive_shuffle_seed("srv", "cli", 42)
      s2 = Fairness.derive_shuffle_seed("srv", "cli", 42)
      assert s1 == s2
    end

    test "changes with different nonces" do
      s1 = Fairness.derive_shuffle_seed("srv", "cli", 1)
      s2 = Fairness.derive_shuffle_seed("srv", "cli", 2)
      refute s1 == s2
    end

    test "changes with different client seeds" do
      s1 = Fairness.derive_shuffle_seed("srv", "alice", 1)
      s2 = Fairness.derive_shuffle_seed("srv", "bob", 1)
      refute s1 == s2
    end

    test "changes with different server seeds" do
      s1 = Fairness.derive_shuffle_seed("seed_a", "cli", 1)
      s2 = Fairness.derive_shuffle_seed("seed_b", "cli", 1)
      refute s1 == s2
    end
  end

  property "commit/verify roundtrip always holds" do
    check all(seed <- binary(length: 32)) do
      commitment = Fairness.commit_server_seed(seed)
      assert Fairness.verify(commitment, seed)
    end
  end

  property "any bit flip in server_seed breaks verification" do
    check all(
            seed <- binary(min_length: 1),
            byte_index <- integer(0..(byte_size(seed) - 1))
          ) do
      commitment = Fairness.commit_server_seed(seed)
      <<pre::binary-size(byte_index), byte, rest::binary>> = seed
      flipped = <<pre::binary, Bitwise.bxor(byte, 0xFF), rest::binary>>

      if seed != flipped do
        refute Fairness.verify(commitment, flipped)
      end
    end
  end
end
