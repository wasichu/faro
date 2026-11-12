defmodule Faro.FaroGame.GameSession do
  @moduledoc """
  Persistent record of a player's game session.

  A session groups one or more rounds together. Status transitions from
  :active to :completed when the player ends the session. Rounds can be
  queried and replayed via the session's audit trail.
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "game_sessions"
    repo(Faro.Repo)
  end

  oban do
    scheduled_actions do
      schedule :cleanup_abandoned_sessions, "0 * * * *" do
        action :cleanup_abandoned_sessions
        worker_module_name Faro.Workers.CleanupAbandonedSessions
        queue :maintenance
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    update :record_activity do
      accept []
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    action :deal_game_turn, :map do
      transaction? true

      touches_resources [
        Faro.FaroGame.Round,
        Faro.FaroGame.Turn,
        Faro.FaroGame.Wallet,
        Faro.FaroGame.LedgerEntry,
        Faro.Audit.Record
      ]

      argument :params, :term, allow_nil?: false
      run Faro.FaroGame.DealTurn
    end

    action :start_game, :map do
      transaction? true
      touches_resources [Faro.FaroGame.Round, Faro.FaroGame.Wallet, Faro.FaroGame.LedgerEntry]
      argument :round_attrs, :map, allow_nil?: false
      run Faro.FaroGame.StartGame
    end

    action :cleanup_abandoned_sessions do
      run Faro.FaroGame.GameSessionCleanup
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:active, :completed]
      default :active
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :rounds, Faro.FaroGame.Round
  end
end
