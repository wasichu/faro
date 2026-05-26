defmodule Faro.Bitcoin do
  @moduledoc """
  Domain for Bitcoin Core regtest integration (future phase).

  Encapsulates all communication with a Bitcoin Core node running in
  regtest mode. Exposes an adapter behaviour so the rest of the system
  remains decoupled from the concrete RPC implementation.

  In v1 (FTC-only), this domain is present as a placeholder. The
  Wallets domain references a `WalletAdapter` behaviour; the FTC
  adapter is used in v1 and this Bitcoin adapter will replace it in v2.
  """

  use Ash.Domain

  resources do
  end
end
