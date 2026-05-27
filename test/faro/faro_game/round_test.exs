defmodule Faro.FaroGame.RoundTest do
  use Faro.DataCase, async: true

  alias Faro.Audit, as: AuditDomain
  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.Audit
  alias Faro.GameEngine.Bet
  alias Faro.GameEngine.Deck
  alias Faro.GameEngine.Fairness
  alias Faro.GameEngine.Round, as: EngineRound
  alias Faro.GameEngine.Shuffle

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp run_full_engine_round do
    server_seed = Fairness.generate_server_seed()
    commitment = Fairness.commit_server_seed(server_seed)
    client_seed = "test-client-seed"
    nonce = 1
    shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
    shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)
    round = EngineRound.new(shuffled_deck)
    {round, shuffled_deck, server_seed, commitment, client_seed, nonce}
  end

  defp deal_all_turns(round, bets \\ []) do
    Enum.reduce(1..25, round, fn _i, r ->
      {_turn, new_round} = EngineRound.deal_turn(r, bets)
      new_round
    end)
  end

  defp round_attrs(shuffled_deck, server_seed, commitment, client_seed, nonce, session_id \\ nil) do
    %{
      game_session_id: session_id,
      nonce: nonce,
      client_seed: client_seed,
      server_seed_hash: commitment,
      server_seed: server_seed,
      algorithm_version: Fairness.algorithm_version(),
      soda_rank: hd(shuffled_deck).rank,
      soda_suit: to_string(hd(shuffled_deck).suit),
      status: :finished,
      shuffled_deck: Serializer.encode_deck(shuffled_deck)
    }
  end

  # ---------------------------------------------------------------------------
  # Basic CRUD
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "persists a round with fairness params" do
      {_engine_round, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()
      attrs = round_attrs(deck, seed, commitment, client_seed, nonce)

      assert {:ok, round} = FaroGame.create_round(attrs)
      assert round.id != nil
      assert round.nonce == nonce
      assert round.client_seed == client_seed
      assert round.server_seed_hash == commitment
      assert round.server_seed == seed
      assert round.algorithm_version == Fairness.algorithm_version()
      assert length(round.shuffled_deck) == 52
    end

    test "stores shuffled deck as card maps" do
      {_engine_round, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()

      {:ok, round} =
        FaroGame.create_round(round_attrs(deck, seed, commitment, client_seed, nonce))

      first = hd(round.shuffled_deck)
      assert Map.has_key?(first, "rank")
      assert Map.has_key?(first, "suit")
    end

    test "can be associated with a session" do
      {:ok, session} = FaroGame.create_session(%{})
      {_, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()
      attrs = round_attrs(deck, seed, commitment, client_seed, nonce, session.id)
      assert {:ok, round} = FaroGame.create_round(attrs)
      assert round.game_session_id == session.id
    end
  end

  describe "get/1" do
    test "reads back a round by id" do
      {_, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()

      {:ok, created} =
        FaroGame.create_round(round_attrs(deck, seed, commitment, client_seed, nonce))

      assert {:ok, fetched} = FaroGame.get_round(created.id)
      assert fetched.id == created.id
      assert fetched.nonce == nonce
    end
  end

  describe "update/2" do
    test "can reveal server seed after round completes" do
      {_, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()

      attrs =
        round_attrs(deck, seed, commitment, client_seed, nonce) |> Map.put(:server_seed, nil)

      {:ok, round} = FaroGame.create_round(attrs)

      assert {:ok, updated} =
               FaroGame.update_round(round, %{server_seed: seed, status: :finished})

      assert updated.server_seed == seed
      assert updated.status == :finished
    end
  end

  # ---------------------------------------------------------------------------
  # Turn persistence
  # ---------------------------------------------------------------------------

  describe "turn persistence" do
    test "persists turns for a round" do
      {engine_round, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()

      {:ok, db_round} =
        FaroGame.create_round(round_attrs(deck, seed, commitment, client_seed, nonce))

      {completed_turn, _new_round} = EngineRound.deal_turn(engine_round, [])

      assert {:ok, turn} =
               FaroGame.create_turn(%{
                 round_id: db_round.id,
                 index: completed_turn.index,
                 loser_rank: completed_turn.loser.rank,
                 loser_suit: to_string(completed_turn.loser.suit),
                 winner_rank: completed_turn.winner.rank,
                 winner_suit: to_string(completed_turn.winner.suit),
                 split: completed_turn.split?,
                 bets: [],
                 settlements: []
               })

      assert turn.index == 1
      assert turn.round_id == db_round.id
    end

    test "persists bet and settlement maps" do
      {engine_round, deck, seed, commitment, client_seed, nonce} = run_full_engine_round()

      {:ok, db_round} =
        FaroGame.create_round(round_attrs(deck, seed, commitment, client_seed, nonce))

      bet = %Bet{rank: 5, amount: 1000, copper?: false}
      {completed_turn, _} = EngineRound.deal_turn(engine_round, [bet])

      encoded_bets = Enum.map(completed_turn.bets, &Serializer.encode_bet/1)
      encoded_settlements = Enum.map(completed_turn.settlements, &Serializer.encode_settlement/1)

      {:ok, turn} =
        FaroGame.create_turn(%{
          round_id: db_round.id,
          index: completed_turn.index,
          loser_rank: completed_turn.loser.rank,
          loser_suit: to_string(completed_turn.loser.suit),
          winner_rank: completed_turn.winner.rank,
          winner_suit: to_string(completed_turn.winner.suit),
          split: completed_turn.split?,
          bets: encoded_bets,
          settlements: encoded_settlements
        })

      assert length(turn.bets) == 1
      assert length(turn.settlements) == 1
      [s] = turn.settlements
      assert s["outcome"] in ["win", "loss", "split", "push"]
    end
  end

  # ---------------------------------------------------------------------------
  # Reconstruction / replay
  # ---------------------------------------------------------------------------

  describe "round replay" do
    test "stored deck can reconstruct the same shuffle via GameEngine" do
      {_engine_round, original_deck, server_seed, commitment, client_seed, nonce} =
        run_full_engine_round()

      {:ok, db_round} =
        FaroGame.create_round(
          round_attrs(original_deck, server_seed, commitment, client_seed, nonce)
        )

      # Reload from DB and decode the deck
      {:ok, loaded} = FaroGame.get_round(db_round.id)
      decoded_deck = Serializer.decode_deck(loaded.shuffled_deck)

      # Reproduce the shuffle from the stored seeds
      shuffle_seed =
        Fairness.derive_shuffle_seed(loaded.server_seed, loaded.client_seed, loaded.nonce)

      reproduced_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)

      assert decoded_deck == reproduced_deck
    end

    test "replayed round produces identical turns" do
      {engine_round, original_deck, server_seed, commitment, client_seed, nonce} =
        run_full_engine_round()

      finished_engine_round = deal_all_turns(engine_round)

      {:ok, db_round} =
        FaroGame.create_round(
          round_attrs(original_deck, server_seed, commitment, client_seed, nonce)
        )

      # Persist all 25 turns
      for engine_turn <- finished_engine_round.turns do
        FaroGame.create_turn!(%{
          round_id: db_round.id,
          index: engine_turn.index,
          loser_rank: engine_turn.loser.rank,
          loser_suit: to_string(engine_turn.loser.suit),
          winner_rank: engine_turn.winner.rank,
          winner_suit: to_string(engine_turn.winner.suit),
          split: engine_turn.split?,
          bets: [],
          settlements: []
        })
      end

      # Reload deck and replay through GameEngine
      {:ok, loaded} = FaroGame.get_round(db_round.id)
      decoded_deck = Serializer.decode_deck(loaded.shuffled_deck)
      replayed_round = EngineRound.new(decoded_deck) |> deal_all_turns()

      # Every turn's cards must match
      for {original, replayed} <- Enum.zip(finished_engine_round.turns, replayed_round.turns) do
        assert original.loser.rank == replayed.loser.rank
        assert original.winner.rank == replayed.winner.rank
        assert original.split? == replayed.split?
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Audit record
  # ---------------------------------------------------------------------------

  describe "audit record" do
    test "persists audit data and verifies" do
      {engine_round, original_deck, server_seed, commitment, client_seed, nonce} =
        run_full_engine_round()

      finished_round = deal_all_turns(engine_round)

      audit =
        Audit.from_round(
          finished_round,
          commitment,
          server_seed,
          client_seed,
          nonce,
          original_deck
        )
        |> Audit.verify_full()

      {:ok, db_round} =
        FaroGame.create_round(
          round_attrs(original_deck, server_seed, commitment, client_seed, nonce)
        )

      assert {:ok, record} =
               AuditDomain.create_audit_record(%{
                 round_id: db_round.id,
                 algorithm_version: audit.algorithm_version,
                 server_commitment: audit.server_commitment,
                 server_seed: audit.server_seed,
                 client_seed: audit.client_seed,
                 nonce: audit.nonce,
                 verified: audit.verified?,
                 shuffled_deck: Serializer.encode_deck(audit.shuffled_deck),
                 soda: Serializer.encode_card(audit.soda),
                 turns: Enum.map(audit.turns, &Serializer.encode_audit_turn/1)
               })

      assert record.verified == true
      assert record.server_commitment == commitment
      assert length(record.shuffled_deck) == 52
      assert record.soda["rank"] == finished_round.soda.rank
    end

    test "get_by_round returns the audit record" do
      {engine_round, deck, server_seed, commitment, client_seed, nonce} = run_full_engine_round()
      finished = deal_all_turns(engine_round)

      audit =
        Audit.from_round(finished, commitment, server_seed, client_seed, nonce, deck)
        |> Audit.verify_full()

      {:ok, db_round} =
        FaroGame.create_round(round_attrs(deck, server_seed, commitment, client_seed, nonce))

      AuditDomain.create_audit_record!(%{
        round_id: db_round.id,
        algorithm_version: audit.algorithm_version,
        server_commitment: audit.server_commitment,
        server_seed: audit.server_seed,
        client_seed: audit.client_seed,
        nonce: audit.nonce,
        verified: audit.verified?,
        shuffled_deck: Serializer.encode_deck(audit.shuffled_deck),
        soda: Serializer.encode_card(audit.soda),
        turns: Enum.map(audit.turns, &Serializer.encode_audit_turn/1)
      })

      assert {:ok, record} = AuditDomain.get_audit_record_by_round(db_round.id)
      assert record.round_id == db_round.id
      assert record.verified == true
    end
  end
end
