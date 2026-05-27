defmodule Faro.FaroGame.Round do
  @moduledoc """
  Persistent record of a single Faro round.

  Stores the fairness parameters (seeds, commitment, nonce), the full
  shuffled deck, the soda card, and current status. Turns are stored
  separately and associated via `round_id`.

  The `server_seed` column is nil until the round is finished — it is
  revealed only after the last card is dealt, matching the provably-fair
  protocol.

  This is a persistence resource. For game logic, see
  `Faro.GameEngine.Round`.
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "game_rounds"
    repo(Faro.Repo)

    references do
      reference(:game_session, on_delete: :delete)
    end
  end

  oban do
    scheduled_actions do
      schedule :cleanup_abandoned_rounds, "*/30 * * * *" do
        action :cleanup_abandoned_rounds
        worker_module_name Faro.Workers.CleanupAbandonedRounds
        queue :maintenance
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    action :cleanup_abandoned_rounds do
      run Faro.FaroGame.RoundCleanup
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :nonce, :integer do
      allow_nil? false
      public? true
    end

    attribute :client_seed, :string do
      allow_nil? false
      public? true
    end

    attribute :server_seed_hash, :string do
      allow_nil? false
      public? true
    end

    # Revealed only after round completion.
    attribute :server_seed, :binary do
      allow_nil? true
      public? true
    end

    attribute :algorithm_version, :string do
      allow_nil? false
      public? true
    end

    attribute :soda_rank, :integer do
      allow_nil? false
      public? true
    end

    attribute :soda_suit, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:dealing, :call_the_turn, :finished]
      default :dealing
      allow_nil? false
      public? true
    end

    # Full 52-card deck in deal order, stored as [{rank, suit}, ...] maps.
    attribute :shuffled_deck, {:array, :map} do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :game_session, Faro.FaroGame.GameSession do
      allow_nil? true
      public? true
    end

    has_many :turns, Faro.FaroGame.Turn
    has_one :audit_record, Faro.Audit.Record
  end
end
