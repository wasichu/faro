defmodule Faro.Wallets do
  @moduledoc """
  Domain for wallet and balance management.

  Owns the append-only ledger of token movements (FTC in v1, Bitcoin
  regtest in a future phase). No funds are mutated in place — every
  credit or debit produces an immutable ledger entry. Balances are
  derived by summing ledger entries for a given account.

  Architectural boundary: Wallets never calls into Faro.GameEngine.
  Game outcomes are translated into ledger entries by Faro.FaroGame.
  """

  use Ash.Domain

  resources do
  end
end
