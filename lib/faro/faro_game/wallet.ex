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

  alias Faro.FaroGame.LedgerEntry

  @starting_balance 1_000_000

  postgres do
    table "wallets"
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
  # Business logic
  # ---------------------------------------------------------------------------

  @doc """
  Creates a wallet and records the initial FTC topup in a single transaction.
  Returns `{:ok, wallet}` or `{:error, reason}`.
  """
  def create_with_topup(attrs \\ %{}) do
    Faro.Repo.transaction(fn ->
      wallet =
        case __MODULE__.create(Map.merge(%{balance_sats: @starting_balance}, attrs)) do
          {:ok, w} -> w
          {:error, e} -> Faro.Repo.rollback(e)
        end

      case LedgerEntry.create(%{
             wallet_id: wallet.id,
             amount_sats: @starting_balance,
             entry_type: :topup,
             note: "FTC starting balance"
           }) do
        {:ok, _} -> wallet
        {:error, e} -> Faro.Repo.rollback(e)
      end
    end)
  end

  @doc """
  Records ledger entries for a completed engine turn and updates the cached
  balance in a single transaction.

  - One `:bet_debit` entry per bet placed (negative amount).
  - One `:payout_credit` entry per settlement that returns anything positive.
  - Balance is set to `post_deal_balance` (computed by the engine).

  Returns `{:ok, updated_wallet}` or `{:error, reason}`.
  Turns with no bets are a no-op and return `{:ok, wallet}` immediately.
  """
  def record_turn(wallet, completed_turn, post_deal_balance, opts \\ []) do
    if completed_turn.bets == [] do
      {:ok, wallet}
    else
      round_id = Keyword.get(opts, :round_id)
      turn_index = Keyword.get(opts, :turn_index)

      Faro.Repo.transaction(fn ->
        Enum.each(completed_turn.bets, fn bet ->
          case LedgerEntry.create(%{
                 wallet_id: wallet.id,
                 amount_sats: -bet.amount,
                 entry_type: :bet_debit,
                 round_id: round_id,
                 turn_index: turn_index
               }) do
            {:ok, _} -> :ok
            {:error, e} -> Faro.Repo.rollback(e)
          end
        end)

        Enum.each(completed_turn.settlements, fn settlement ->
          payout = settlement.bet.amount + settlement.net

          if payout > 0 do
            case LedgerEntry.create(%{
                   wallet_id: wallet.id,
                   amount_sats: payout,
                   entry_type: :payout_credit,
                   round_id: round_id,
                   turn_index: turn_index
                 }) do
              {:ok, _} -> :ok
              {:error, e} -> Faro.Repo.rollback(e)
            end
          end
        end)

        case __MODULE__.update(wallet, %{balance_sats: post_deal_balance}) do
          {:ok, updated} -> updated
          {:error, e} -> Faro.Repo.rollback(e)
        end
      end)
    end
  end
end
