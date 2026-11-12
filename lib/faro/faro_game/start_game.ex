defmodule Faro.FaroGame.StartGame do
  @moduledoc "Creates an anonymous session, funded wallet, and first round atomically."
  use Ash.Resource.Actions.Implementation

  alias Faro.FaroGame

  @impl true
  def run(input, _opts, _context) do
    with {:ok, session} <- FaroGame.create_session(%{}),
         {:ok, wallet} <- FaroGame.create_wallet_with_topup(%{game_session_id: session.id}),
         attrs = Map.put(input.arguments.round_attrs, :game_session_id, session.id),
         {:ok, round} <- FaroGame.create_round(attrs) do
      {:ok, %{session: session, wallet: wallet, round: round}}
    end
  end
end
