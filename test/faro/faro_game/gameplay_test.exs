defmodule Faro.FaroGame.GameplayTest do
  use Faro.DataCase, async: true

  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Bet, Deck, Fairness, Shuffle}

  defp game do
    seed = :binary.copy(<<7>>, 32)
    client = "test-client"
    deck = Shuffle.shuffle(Deck.new(), Fairness.derive_shuffle_seed(seed, client, 1))

    attrs = %{
      nonce: 1,
      client_seed: client,
      server_seed_hash: Fairness.commit_server_seed(seed),
      algorithm_version: Fairness.algorithm_version(),
      soda_rank: hd(deck).rank,
      soda_suit: to_string(hd(deck).suit),
      shuffled_deck: Serializer.encode_deck(deck)
    }

    game = FaroGame.start_game!(attrs)
    {game, seed}
  end

  defp params(game, seed, index, bets \\ []) do
    %{
      round_id: game.round.id,
      wallet_id: game.wallet.id,
      server_seed: seed,
      expected_index: index,
      bets: bets
    }
  end

  test "commits full game, ledger, and verified audit" do
    {game, seed} = game()

    for index <- 1..25 do
      assert {:ok, result} = FaroGame.deal_game_turn(params(game, seed, index))
      assert result.turn.index == index
    end

    round = FaroGame.get_round!(game.round.id)
    assert round.status == :finished
    assert round.server_seed == seed
    assert Faro.Audit.get_audit_record_by_round!(round.id).verified
    assert length(FaroGame.list_turns_for_round!(round.id)) == 25
  end

  test "rejects replayed turn and wallet from another session" do
    {game, seed} = game()
    {other, _} = game()

    assert {:error, _} =
             FaroGame.deal_game_turn(%{params(game, seed, 1) | wallet_id: other.wallet.id})

    assert {:ok, _} = FaroGame.deal_game_turn(params(game, seed, 1))
    assert {:error, _} = FaroGame.deal_game_turn(params(game, seed, 1))
    assert length(FaroGame.list_turns_for_round!(game.round.id)) == 1
  end

  test "rejects unfunded and malformed wagers without writing a turn" do
    {game, seed} = game()

    for bet <- [
          %Bet{rank: 1, amount: 1_000_001},
          %Bet{rank: 0, amount: 1},
          %Bet{rank: 1, amount: -1}
        ] do
      assert {:error, _} = FaroGame.deal_game_turn(params(game, seed, 1, [bet]))
    end

    assert FaroGame.list_turns_for_round!(game.round.id) == []
    assert FaroGame.get_wallet!(game.wallet.id).balance_sats == 1_000_000
  end

  test "failed final audit rolls back all turn writes and seed reveal" do
    {game, seed} = game()
    for index <- 1..24, do: FaroGame.deal_game_turn!(params(game, seed, index))
    before_entries = FaroGame.list_ledger_entries_for_wallet!(game.wallet.id)
    bet = %Faro.GameEngine.CallTheTurnBet{predicted_loser: 1, predicted_winner: 2, amount: 100}
    assert {:error, _} = FaroGame.deal_game_turn(params(game, <<0::256>>, 25, [bet]))
    assert length(FaroGame.list_turns_for_round!(game.round.id)) == 24
    assert FaroGame.get_round!(game.round.id).server_seed == nil
    assert FaroGame.list_ledger_entries_for_wallet!(game.wallet.id) == before_entries
  end

  test "startup failure rolls back session, wallet, and initial funding" do
    counts =
      {Ash.count!(FaroGame.GameSession), Ash.count!(FaroGame.Wallet),
       Ash.count!(FaroGame.LedgerEntry)}

    assert {:error, _} = FaroGame.start_game(%{})

    assert counts ==
             {Ash.count!(FaroGame.GameSession), Ash.count!(FaroGame.Wallet),
              Ash.count!(FaroGame.LedgerEntry)}
  end

  test "a late audit insertion failure rolls back turn, balance, and seed reveal" do
    {game, seed} = game()
    for index <- 1..24, do: FaroGame.deal_game_turn!(params(game, seed, index))
    round = FaroGame.get_round!(game.round.id)

    Faro.Audit.create_audit_record!(%{
      round_id: round.id,
      algorithm_version: round.algorithm_version,
      server_commitment: round.server_seed_hash,
      server_seed: seed,
      client_seed: round.client_seed,
      nonce: round.nonce,
      shuffled_deck: round.shuffled_deck,
      soda: %{"rank" => round.soda_rank, "suit" => round.soda_suit},
      turns: []
    })

    entries = FaroGame.list_ledger_entries_for_wallet!(game.wallet.id)
    [loser, winner, _] = Enum.take(round.shuffled_deck, -3)

    bet = %Faro.GameEngine.CallTheTurnBet{
      predicted_loser: loser["rank"],
      predicted_winner: winner["rank"],
      amount: 100
    }

    assert {:error, _} = FaroGame.deal_game_turn(params(game, seed, 25, [bet]))
    assert length(FaroGame.list_turns_for_round!(game.round.id)) == 24
    assert FaroGame.get_wallet!(game.wallet.id).balance_sats == game.wallet.balance_sats
    assert FaroGame.get_round!(game.round.id).status == :call_the_turn
    assert FaroGame.get_round!(game.round.id).server_seed == nil
    assert FaroGame.list_ledger_entries_for_wallet!(game.wallet.id) == entries
  end

  test "does not continue from a corrupted persisted turn" do
    {game, seed} = game()
    FaroGame.deal_game_turn!(params(game, seed, 1))
    [turn] = FaroGame.list_turns_for_round!(game.round.id)
    import Ecto.Query

    from(row in FaroGame.Turn, where: row.id == ^turn.id)
    |> Faro.Repo.update_all(set: [split: not turn.split])

    assert {:error, _} = FaroGame.deal_game_turn(params(game, seed, 2))
    assert length(FaroGame.list_turns_for_round!(game.round.id)) == 1
  end

  test "every deal refreshes activity even when round and session status are unchanged" do
    {game, seed} = game()
    import Ecto.Query
    past = DateTime.add(DateTime.utc_now(), -86_400, :second)

    from(row in FaroGame.Round, where: row.id == ^game.round.id)
    |> Faro.Repo.update_all(set: [updated_at: past])

    from(row in FaroGame.GameSession, where: row.id == ^game.session.id)
    |> Faro.Repo.update_all(set: [updated_at: past])

    assert {:ok, _} = FaroGame.deal_game_turn(params(game, seed, 1))
    session = FaroGame.get_session!(game.session.id)
    round = FaroGame.get_round!(game.round.id)
    assert session.status == :active
    assert round.status == :dealing
    assert DateTime.compare(session.updated_at, past) == :gt
    assert DateTime.compare(round.updated_at, past) == :gt
  end
end
