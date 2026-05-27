defmodule Faro.FaroGame do
  @moduledoc """
  Domain for Faro game persistence and lifecycle management.

  This is the persistence and coordination layer that sits between the
  pure `Faro.GameEngine` and the rest of the system. It stores game
  sessions, rounds, turns, and outcomes in the database.

  Architectural boundary: FaroGame calls into Faro.GameEngine for all
  game logic, but GameEngine never calls back into FaroGame.
  """

  use Ash.Domain

  resources do
    resource Faro.FaroGame.GameSession do
      define :create_session, action: :create
      define :get_session, action: :read, get_by: :id
      define :update_session, action: :update
    end

    resource Faro.FaroGame.Round do
      define :create_round, action: :create
      define :get_round, action: :read, get_by: :id
      define :update_round, action: :update
    end

    resource Faro.FaroGame.Turn do
      define :create_turn, action: :create
    end

    resource Faro.FaroGame.Wallet do
      define :create_wallet_with_topup, action: :create_with_topup
      define :get_wallet, action: :read, get_by: :id
      define :update_wallet, action: :update
      define :record_wallet_turn, action: :record_turn
    end

    resource Faro.FaroGame.LedgerEntry do
      define :create_ledger_entry, action: :create
      define :list_ledger_entries, action: :read
      define :list_ledger_entries_for_wallet, action: :by_wallet, args: [:wallet_id]
    end
  end
end
