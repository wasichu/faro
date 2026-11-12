defmodule Faro.GameEngine.IntegrityTest do
  use ExUnit.Case, async: true

  alias Faro.GameEngine.{Audit, Bet, Deck, Fairness, Round, Shuffle}

  defp transcript do
    seed = :binary.copy(<<42>>, 32)
    deck = Shuffle.shuffle(Deck.new(), Fairness.derive_shuffle_seed(seed, "client", 1))

    round =
      Enum.reduce(1..25, Round.new(deck), fn _, round ->
        bets = if round.phase == :dealing, do: [%Bet{rank: 1, amount: 100}], else: []
        {_, next} = Round.deal_turn(round, bets)
        next
      end)

    Audit.from_round(round, Fairness.commit_server_seed(seed), seed, "client", 1, deck)
  end

  test "full verification rejects incomplete, duplicate, or reordered turn history" do
    audit = transcript()
    assert Audit.verify_full(audit).verified?
    [first | rest] = audit.turns

    for turns <- [
          [],
          rest,
          [first, first | Enum.drop(rest, 1)],
          Enum.reverse(audit.turns),
          audit.turns ++ [first]
        ] do
      refute Audit.verify_full(%{audit | turns: turns}).verified?
    end
  end

  test "full verification rejects tampered split flags, bets, payouts, and removed settlements" do
    audit = transcript()
    [turn | rest] = audit.turns
    [settlement] = turn.settlements

    for changed <- [
          %{turn | split?: not turn.split?},
          %{turn | bets: []},
          Map.delete(turn, :bets),
          %{turn | settlements: []},
          %{turn | settlements: [%{settlement | net: settlement.net + 1}]},
          %{turn | settlements: [%{settlement | bet: %{settlement.bet | amount: 200}}]}
        ] do
      refute Audit.verify_full(%{audit | turns: [changed | rest]}).verified?
    end
  end

  test "full verification rejects unsupported algorithms and malformed metadata" do
    audit = transcript()

    for changed <- [
          %{audit | algorithm_version: "faro-shuffle-v999"},
          %{audit | nonce: -1},
          %{audit | nonce: 18_446_744_073_709_551_616},
          %{audit | turns: [nil]},
          %{audit | server_seed: nil}
        ] do
      refute Audit.verify_full(changed).verified?
    end
  end

  test "nonce encoding rejects underflow and overflow instead of wrapping" do
    for nonce <- [-1, 18_446_744_073_709_551_616, "1"] do
      assert_raise ArgumentError, fn ->
        Fairness.derive_shuffle_seed("server", "client", nonce)
      end
    end
  end

  test "empty and singleton shuffles terminate without changing cards" do
    assert Shuffle.shuffle([], <<0::256>>) == []
    [card | _] = Deck.new()
    assert Shuffle.shuffle([card], <<0::256>>) == [card]
  end

  test "versioned shuffle matches the independent v1 golden vector" do
    assert Deck.serialize(Shuffle.shuffle(Deck.new(), <<0::256>>)) ==
             ~w(2h Ah 7h 6h 10h Ad 8h 2s Jc Qd 10s 3d 3h Js 2d 8c Kd Ac 5d 8d 3c Jh 5c 10c 8s Qs As 6d Jd Qc 9c 4c 6c 4h Ks 6s 10d 5h Kh 2c 7s 9s Qh 9d Kc 5s 4d 4s 7d 7c 9h 3s)
  end

  test "round construction rejects incomplete or duplicated decks" do
    deck = Deck.new()

    for invalid <- [[], tl(deck), [hd(deck) | tl(tl(deck))] ++ [hd(deck)]] do
      assert_raise ArgumentError, fn -> Round.new(invalid) end
    end
  end
end
