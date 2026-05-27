defmodule Faro.FaroGame.Wallet do
  @moduledoc """
  FTC (fake token coin) wallet for a game session.

  Holds a cached `balance_sats` that is always equal to the sum of all
  associated `LedgerEntry` records. Balance changes must go through
  `record_turn/4` or `create_with_topup/1` — never by updating
  `balance_sats` directly — to guarantee the ledger stays in sync.

  This resource owns no game logic. It is a persistence + accounting
  boundary only.
  """

  use Ash.Resource,
    domain: Faro.FaroGame,
    data_layer: AshPostgres.DataLayer

  @starting_balance 1_000_000

  postgres do
    table "wallets"
    repo(Faro.Repo)
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create_with_topup do
      accept [:game_session_id]

      change set_attribute(:balance_sats, @starting_balance)

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, wallet ->
          Ash.create!(
            Faro.FaroGame.LedgerEntry,
            %{
              wallet_id: wallet.id,
              amount_sats: @starting_balance,
              entry_type: :topup,
              note: "FTC starting balance"
            },
            domain: Faro.FaroGame
          )

          {:ok, wallet}
        end)
      end
    end

    update :record_turn do
      require_atomic? false

      argument :bets, {:array, :map}, allow_nil?: false
      argument :settlements, {:array, :map}, allow_nil?: false
      argument :post_deal_balance, :integer, allow_nil?: false
      argument :round_id, :uuid, allow_nil?: true
      argument :turn_index, :integer, allow_nil?: true

      change fn changeset, _context ->
        balance = Ash.Changeset.get_argument(changeset, :post_deal_balance)

        changeset
        |> Ash.Changeset.change_attribute(:balance_sats, balance)
        |> Ash.Changeset.after_action(fn changeset, wallet ->
          bets = Ash.Changeset.get_argument(changeset, :bets)
          settlements = Ash.Changeset.get_argument(changeset, :settlements)
          round_id = Ash.Changeset.get_argument(changeset, :round_id)
          turn_index = Ash.Changeset.get_argument(changeset, :turn_index)

          Enum.each(bets, fn bet ->
            Ash.create!(
              Faro.FaroGame.LedgerEntry,
              %{
                wallet_id: wallet.id,
                amount_sats: -bet.amount,
                entry_type: :bet_debit,
                round_id: round_id,
                turn_index: turn_index
              },
              domain: Faro.FaroGame
            )
          end)

          Enum.each(settlements, fn s ->
            payout = s.bet.amount + s.net

            if payout > 0 do
              Ash.create!(
                Faro.FaroGame.LedgerEntry,
                %{
                  wallet_id: wallet.id,
                  amount_sats: payout,
                  entry_type: :payout_credit,
                  round_id: round_id,
                  turn_index: turn_index
                },
                domain: Faro.FaroGame
              )
            end
          end)

          {:ok, wallet}
        end)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :balance_sats, :integer do
      default 0
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

    has_many :ledger_entries, Faro.FaroGame.LedgerEntry
  end

  # ---------------------------------------------------------------------------
  # Public API — thin wrappers that convert engine structs to action arguments.
  # These preserve the existing call signature used by PlayLive and tests.
  # ---------------------------------------------------------------------------

  @doc """
  Creates a wallet with the starting balance and a corresponding topup ledger
  entry, all in a single Ash-managed transaction.
  """
  def create_with_topup(attrs \\ %{}) do
    Faro.FaroGame.create_wallet_with_topup(attrs)
  end

  @doc """
  Records ledger entries for a completed engine turn and updates the cached
  balance in a single transaction.

  Turns with no bets are a no-op.
  """
  def record_turn(wallet, completed_turn, post_deal_balance, opts \\ []) do
    if completed_turn.bets == [] do
      {:ok, wallet}
    else
      bets = Enum.map(completed_turn.bets, fn bet -> %{amount: bet.amount} end)

      settlements =
        Enum.map(completed_turn.settlements, fn s ->
          %{net: s.net, bet: %{amount: s.bet.amount}}
        end)

      Faro.FaroGame.record_wallet_turn(wallet, %{
        bets: bets,
        settlements: settlements,
        post_deal_balance: post_deal_balance,
        round_id: Keyword.get(opts, :round_id),
        turn_index: Keyword.get(opts, :turn_index)
      })
    end
  end

  @doc "Fetches a wallet by id."
  def get(id), do: Faro.FaroGame.get_wallet(id)
end
