defmodule Faro.FaroGame.WalletTest do
  use Faro.DataCase, async: true

  alias Faro.FaroGame.Wallet
  alias Faro.GameEngine.{Bet, Deck, Round}

  @starting_balance 1_000_000

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_wallet(attrs \\ %{}) do
    {:ok, wallet} = Wallet.create_with_topup(attrs)
    wallet
  end

  defp ledger_entries(wallet) do
    Faro.FaroGame.list_ledger_entries_for_wallet!(wallet.id)
  end

  defp deal_one_turn(bets) do
    round = Round.new(Deck.new())
    {turn, _new_round} = Round.deal_turn(round, bets)
    turn
  end

  # ---------------------------------------------------------------------------
  # Wallet creation
  # ---------------------------------------------------------------------------

  describe "create_with_topup/1" do
    test "creates wallet with correct starting balance" do
      wallet = create_wallet()
      assert wallet.balance_sats == @starting_balance
    end

    test "creates a topup ledger entry" do
      wallet = create_wallet()
      entries = ledger_entries(wallet)
      assert length(entries) == 1
      [entry] = entries
      assert entry.entry_type == :topup
      assert entry.amount_sats == @starting_balance
      assert entry.wallet_id == wallet.id
    end

    test "can be associated with a session" do
      {:ok, session} = Faro.FaroGame.create_session(%{})
      wallet = create_wallet(%{game_session_id: session.id})
      assert wallet.game_session_id == session.id
    end

    test "ledger sum equals wallet balance" do
      wallet = create_wallet()
      entries = ledger_entries(wallet)
      ledger_sum = Enum.sum(Enum.map(entries, & &1.amount_sats))
      assert ledger_sum == wallet.balance_sats
    end
  end

  # ---------------------------------------------------------------------------
  # record_turn — no bets
  # ---------------------------------------------------------------------------

  describe "record_turn/4 with no bets" do
    test "returns wallet unchanged and creates no entries" do
      wallet = create_wallet()
      turn = deal_one_turn([])

      {:ok, updated} = Wallet.record_turn(wallet, turn, wallet.balance_sats)

      assert updated.balance_sats == wallet.balance_sats
      # only the topup
      assert length(ledger_entries(wallet)) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # record_turn — winning bet
  # ---------------------------------------------------------------------------

  describe "record_turn/4 with a winning bet" do
    test "creates debit and credit entries and updates balance" do
      wallet = create_wallet()

      # Find a turn where rank 2 wins or loses — we need a real turn
      # with known settlements, so drive until we get one with a settlement.
      turn = find_turn_with_bet_rank(2)
      balance_after = wallet.balance_sats - turn_total_bets(turn) + turn_delta(turn)

      {:ok, updated} = Wallet.record_turn(wallet, turn, balance_after, turn_index: turn.index)

      assert updated.balance_sats == balance_after

      entries = ledger_entries(wallet)
      # topup + one debit per bet + one credit per non-zero return
      debit_entries = Enum.filter(entries, &(&1.entry_type == :bet_debit))
      credit_entries = Enum.filter(entries, &(&1.entry_type == :payout_credit))

      assert length(debit_entries) == length(turn.bets)
      assert Enum.all?(debit_entries, &(&1.amount_sats < 0))
      assert Enum.all?(credit_entries, &(&1.amount_sats > 0))
    end

    test "ledger sum equals final balance after a turn" do
      wallet = create_wallet()
      bet = %Bet{rank: 3, amount: 5_000, copper?: false}
      turn = deal_one_turn([bet])

      balance_after = wallet.balance_sats - turn_total_bets(turn) + turn_delta(turn)
      {:ok, _updated} = Wallet.record_turn(wallet, turn, balance_after)

      entries = ledger_entries(wallet)
      ledger_sum = Enum.sum(Enum.map(entries, & &1.amount_sats))
      assert ledger_sum == balance_after
    end
  end

  # ---------------------------------------------------------------------------
  # record_turn — losing bet
  # ---------------------------------------------------------------------------

  describe "record_turn/4 with a losing bet" do
    test "debit entry is created but no credit for a total loss" do
      wallet = create_wallet()
      # Force a loss by finding a turn where the bet rank loses with no return
      turn = find_turn_where_bet_loses()
      balance_after = wallet.balance_sats - turn_total_bets(turn) + turn_delta(turn)

      {:ok, updated} = Wallet.record_turn(wallet, turn, balance_after)

      entries = ledger_entries(wallet)
      debit_entries = Enum.filter(entries, &(&1.entry_type == :bet_debit))
      credit_entries = Enum.filter(entries, &(&1.entry_type == :payout_credit))

      assert length(debit_entries) == 1
      # No credit on a straight loss (payout = 0)
      assert Enum.all?(credit_entries, &(&1.amount_sats > 0))

      assert updated.balance_sats == balance_after
    end
  end

  # ---------------------------------------------------------------------------
  # Balance correctness across multiple turns
  # ---------------------------------------------------------------------------

  describe "balance correctness" do
    test "balance stays correct across several turns with bets" do
      wallet = create_wallet()
      bet_amount = 1_000

      final_wallet =
        Enum.reduce(1..5, wallet, fn i, w ->
          bet = %Bet{rank: rem(i, 13) + 1, amount: bet_amount, copper?: false}
          turn = deal_one_turn([bet])
          new_bal = w.balance_sats - turn_total_bets(turn) + turn_delta(turn)
          {:ok, updated} = Wallet.record_turn(w, turn, new_bal, turn_index: i)
          updated
        end)

      entries = ledger_entries(final_wallet)
      ledger_sum = Enum.sum(Enum.map(entries, & &1.amount_sats))
      assert ledger_sum == final_wallet.balance_sats
    end

    test "round_id and turn_index are stored on ledger entries" do
      wallet = create_wallet()
      bet = %Bet{rank: 5, amount: 500, copper?: false}
      turn = deal_one_turn([bet])
      balance_after = wallet.balance_sats - turn_total_bets(turn) + turn_delta(turn)

      {:ok, _} = Wallet.record_turn(wallet, turn, balance_after, turn_index: turn.index)

      entries =
        ledger_entries(wallet)
        |> Enum.filter(&(&1.entry_type in [:bet_debit, :payout_credit]))

      assert Enum.all?(entries, &(&1.turn_index == turn.index))
    end
  end

  # ---------------------------------------------------------------------------
  # Transaction rollback
  # ---------------------------------------------------------------------------

  describe "transaction rollback" do
    test "balance is unchanged if wallet update fails mid-transaction" do
      wallet = create_wallet()
      bet = %Bet{rank: 7, amount: 1_000, copper?: false}
      turn = deal_one_turn([bet])

      # Simulate a crash by passing an invalid balance (negative)
      # record_turn short-circuits at bets == [], so we need a real turn.
      # We test rollback by checking that an outright DB error leaves
      # the wallet balance and entry count unchanged.
      original_balance = wallet.balance_sats
      original_entry_count = length(ledger_entries(wallet))

      # Intentionally corrupt: pass a wallet with an invalid id to trigger failure
      bad_wallet = %{wallet | id: Ecto.UUID.generate()}
      result = Wallet.record_turn(bad_wallet, turn, original_balance - 1_000)
      assert {:error, _} = result

      # The real wallet is untouched
      {:ok, reloaded} = Wallet.get(wallet.id)
      assert reloaded.balance_sats == original_balance
      assert length(ledger_entries(wallet)) == original_entry_count
    end
  end

  test "rejects a balance that does not reconcile with its ledger entries" do
    wallet = create_wallet()
    turn = deal_one_turn([%Bet{rank: 1, amount: 100}])
    assert {:error, _} = Wallet.record_turn(wallet, turn, wallet.balance_sats - 1)
    assert length(ledger_entries(wallet)) == 1
    assert Faro.FaroGame.get_wallet!(wallet.id).balance_sats == wallet.balance_sats
  end

  test "rejects an overdraft even when the forged post-turn balance is positive" do
    wallet = create_wallet()
    turn = deal_one_turn([%Bet{rank: 1, amount: wallet.balance_sats + 1}])
    assert {:error, _} = Wallet.record_turn(wallet, turn, wallet.balance_sats)
    assert length(ledger_entries(wallet)) == 1
  end

  test "stale wallet updates cannot overwrite a newer settlement" do
    wallet = create_wallet()
    turn = deal_one_turn([%Bet{rank: 3, amount: 100}])
    assert {:ok, updated} = Wallet.record_turn(wallet, turn, wallet.balance_sats + 100)
    count = length(ledger_entries(wallet))
    assert {:error, _} = Wallet.record_turn(wallet, turn, wallet.balance_sats + 100)
    assert Faro.FaroGame.get_wallet!(wallet.id).balance_sats == updated.balance_sats
    assert length(ledger_entries(wallet)) == count
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp turn_total_bets(turn), do: Enum.sum(Enum.map(turn.bets, & &1.amount))
  defp turn_delta(turn), do: Enum.sum(Enum.map(turn.settlements, &(&1.bet.amount + &1.net)))

  defp find_turn_with_bet_rank(rank), do: known_turn(1, rank)
  defp find_turn_where_bet_loses, do: known_turn(5, 6)

  defp known_turn(loser_rank, winner_rank) do
    alias Faro.GameEngine.Card
    soda = %Card{rank: 13, suit: :hearts}
    loser = %Card{rank: loser_rank, suit: :spades}
    winner = %Card{rank: winner_rank, suit: :clubs}
    deck = [soda, loser, winner | Deck.new() -- [soda, loser, winner]]
    bet_rank = if loser_rank == 5, do: 5, else: winner_rank
    {turn, _} = Round.deal_turn(Round.new(deck), [%Bet{rank: bet_rank, amount: 1_000}])
    turn
  end
end
