defmodule Faro.FaroGame.CleanupTest do
  use Faro.DataCase, async: true

  import Ecto.Query

  alias Faro.FaroGame
  alias Faro.FaroGame.{GameSession, Round}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_session!(attrs \\ %{}) do
    Ash.create!(GameSession, attrs, domain: FaroGame, authorize?: false)
  end

  defp create_round!(session) do
    Ash.create!(
      Round,
      %{
        game_session_id: session.id,
        nonce: 1,
        client_seed: "test-seed",
        server_seed_hash: String.duplicate("a", 64),
        algorithm_version: "v1",
        soda_rank: 1,
        soda_suit: "spades",
        shuffled_deck: []
      },
      domain: FaroGame,
      authorize?: false
    )
  end

  defp age_record(table, id, hours_ago) do
    past = DateTime.add(DateTime.utc_now(), -hours_ago * 3600, :second)
    binary_id = Ecto.UUID.dump!(id)

    from(r in table, where: r.id == ^binary_id)
    |> Faro.Repo.update_all(set: [updated_at: past])
  end

  defp run_session_cleanup! do
    GameSession
    |> Ash.ActionInput.for_action(:cleanup_abandoned_sessions, %{}, authorize?: false)
    |> Ash.run_action!()
  end

  defp run_round_cleanup! do
    Round
    |> Ash.ActionInput.for_action(:cleanup_abandoned_rounds, %{}, authorize?: false)
    |> Ash.run_action!()
  end

  # ---------------------------------------------------------------------------
  # Session cleanup
  # ---------------------------------------------------------------------------

  describe "GameSessionCleanup" do
    setup do
      Application.put_env(:faro, :cleanup, session_retention_hours: 1, round_retention_hours: 1)
      on_exit(fn -> Application.delete_env(:faro, :cleanup) end)
      :ok
    end

    test "deletes active sessions older than retention threshold" do
      session = create_session!()
      age_record("game_sessions", session.id, 2)

      assert :ok = run_session_cleanup!()

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(GameSession, session.id, domain: FaroGame, authorize?: false)
    end

    test "does not delete active sessions within retention threshold" do
      session = create_session!()

      assert :ok = run_session_cleanup!()

      assert {:ok, _} = Ash.get(GameSession, session.id, domain: FaroGame, authorize?: false)
    end

    test "does not delete completed sessions regardless of age" do
      session = create_session!(%{status: :completed})
      age_record("game_sessions", session.id, 48)

      assert :ok = run_session_cleanup!()

      assert {:ok, _} = Ash.get(GameSession, session.id, domain: FaroGame, authorize?: false)
    end

    test "cascade-deletes rounds when session is deleted" do
      session = create_session!()
      round = create_round!(session)
      age_record("game_sessions", session.id, 2)

      assert :ok = run_session_cleanup!()

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(GameSession, session.id, domain: FaroGame, authorize?: false)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Round, round.id, domain: FaroGame, authorize?: false)
    end
  end

  # ---------------------------------------------------------------------------
  # Round cleanup
  # ---------------------------------------------------------------------------

  describe "RoundCleanup" do
    setup do
      Application.put_env(:faro, :cleanup, session_retention_hours: 1, round_retention_hours: 1)
      on_exit(fn -> Application.delete_env(:faro, :cleanup) end)
      :ok
    end

    test "deletes dealing rounds older than retention threshold" do
      session = create_session!()
      round = create_round!(session)
      assert round.status == :dealing
      age_record("game_rounds", round.id, 2)

      assert :ok = run_round_cleanup!()

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Round, round.id, domain: FaroGame, authorize?: false)
    end

    test "does not delete rounds within retention threshold" do
      session = create_session!()
      round = create_round!(session)

      assert :ok = run_round_cleanup!()

      assert {:ok, _} = Ash.get(Round, round.id, domain: FaroGame, authorize?: false)
    end

    test "does not delete finished rounds regardless of age" do
      session = create_session!()
      round = create_round!(session)

      Ash.update!(round, %{status: :finished}, domain: FaroGame, authorize?: false)
      age_record("game_rounds", round.id, 48)

      assert :ok = run_round_cleanup!()

      assert {:ok, _} = Ash.get(Round, round.id, domain: FaroGame, authorize?: false)
    end
  end
end
