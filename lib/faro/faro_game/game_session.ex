defmodule Faro.FaroGame.GameSession do
  @moduledoc """
  Persistent record of a player's game session.

  A session groups one or more rounds together. Status transitions from
  :active to :completed when the player ends the session. Rounds can be
  queried and replayed via the session's audit trail.
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "game_sessions"
    repo Faro.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  code_interface do
    define :create, action: :create
    define :get, action: :read, get_by: :id
    define :update, action: :update
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
