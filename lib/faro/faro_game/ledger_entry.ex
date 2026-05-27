defmodule Faro.FaroGame.LedgerEntry do
  @moduledoc """
  Append-only ledger entry for an FTC wallet.

  `amount_sats` is signed: positive values are credits (money in),
  negative values are debits (money out). Every balance change on a
  `Wallet` must produce at least one `LedgerEntry` so the full history
  is auditable and the cached `balance_sats` can always be verified by
  summing the ledger.

  Entry types:
  - `:topup`          — initial FTC grant at wallet creation
  - `:bet_debit`      — funds committed for a bet on a dealt turn
  - `:payout_credit`  — funds returned after a winning or pushed bet
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ledger_entries"
    repo(Faro.Repo)
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_wallet do
      argument :wallet_id, :uuid, allow_nil?: false
      filter expr(wallet_id == ^arg(:wallet_id))
      prepare build(sort: [:inserted_at])
    end
  end

  attributes do
    uuid_primary_key :id

    # Signed integer: positive = credit, negative = debit.
    attribute :amount_sats, :integer do
      allow_nil? false
      public? true
    end

    attribute :entry_type, :atom do
      constraints one_of: [:topup, :bet_debit, :payout_credit]
      allow_nil? false
      public? true
    end

    attribute :note, :string do
      allow_nil? true
      public? true
    end

    # Turn number within the round (1–25), null for non-turn entries.
    attribute :turn_index, :integer do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :wallet, Faro.FaroGame.Wallet do
      allow_nil? false
      public? true
    end

    belongs_to :round, Faro.FaroGame.Round do
      allow_nil? true
      public? true
    end
  end
end
