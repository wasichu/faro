defmodule Faro.Audit.Record do
  @moduledoc """
  Provably-fair audit record for a completed Faro round.

  Contains everything required to independently verify that a round was
  dealt correctly: the seed commitment published before play, the server
  seed revealed after play, the client seed, the nonce, the full
  shuffled deck, the soda card, and a turn-by-turn transcript.

  `verified` is set at write time by running
  `Faro.GameEngine.Audit.verify_full/1` before persistence — it is a
  cached result, not recomputed on read.

  This is a persistence resource. For audit logic, see
  `Faro.GameEngine.Audit`.
  """

  use Ash.Resource,
    domain: Faro.Audit,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "audit_records"
    repo(Faro.Repo)
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :algorithm_version, :string do
      allow_nil? false
      public? true
    end

    attribute :server_commitment, :string do
      allow_nil? false
      public? true
    end

    attribute :server_seed, :binary do
      allow_nil? false
      public? true
    end

    attribute :client_seed, :string do
      allow_nil? false
      public? true
    end

    attribute :nonce, :integer do
      allow_nil? false
      public? true
    end

    attribute :verified, :boolean do
      default false
      allow_nil? false
      public? true
    end

    # Full 52-card shuffled deck as card maps.
    attribute :shuffled_deck, {:array, :map} do
      allow_nil? false
      public? true
    end

    # The burned first card (soda) as a card map.
    attribute :soda, :map do
      allow_nil? false
      public? true
    end

    # Turn-by-turn transcript as serialized maps.
    attribute :turns, {:array, :map} do
      default []
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :round, Faro.FaroGame.Round do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_round, [:round_id]
  end
end
