defmodule Faro.FaroGame.Turn do
  @moduledoc """
  Persistent record of a single dealt turn within a round.

  Bets and settlements are stored as JSON maps rather than normalized
  tables — they are always read together with the turn and their schema
  is stable.

  This is a persistence resource. For game logic, see
  `Faro.GameEngine.Turn`.
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "game_turns"
    repo Faro.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    # Turn number within the round (1–25).
    attribute :index, :integer do
      allow_nil? false
      public? true
    end

    attribute :loser_rank, :integer do
      allow_nil? false
      public? true
    end

    attribute :loser_suit, :string do
      allow_nil? false
      public? true
    end

    attribute :winner_rank, :integer do
      allow_nil? false
      public? true
    end

    attribute :winner_suit, :string do
      allow_nil? false
      public? true
    end

    attribute :split, :boolean do
      default false
      allow_nil? false
      public? true
    end

    # Serialized bet maps — see Faro.FaroGame.Serializer.
    attribute :bets, {:array, :map} do
      default []
      public? true
    end

    # Serialized settlement maps — see Faro.FaroGame.Serializer.
    attribute :settlements, {:array, :map} do
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
end
