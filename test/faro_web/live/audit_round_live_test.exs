defmodule FaroWeb.AuditRoundLiveTest do
  use FaroWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Deck, Fairness, Shuffle}

  test "missing or invalid round IDs render a not-found page", %{conn: conn} do
    for id <- [Ecto.UUID.generate(), "invalid"] do
      {:ok, view, _} = live(conn, "/audit/rounds/#{id}")
      assert has_element?(view, "#round-not-found")
    end
  end

  test "a finished round without turns fails verification", %{conn: conn} do
    seed = :binary.copy(<<42>>, 32)
    deck = Shuffle.shuffle(Deck.new(), Fairness.derive_shuffle_seed(seed, "client", 1))

    round =
      FaroGame.create_round!(%{
        nonce: 1,
        client_seed: "client",
        server_seed: seed,
        server_seed_hash: Fairness.commit_server_seed(seed),
        algorithm_version: Fairness.algorithm_version(),
        shuffled_deck: Serializer.encode_deck(deck),
        soda_rank: hd(deck).rank,
        soda_suit: to_string(hd(deck).suit),
        status: :finished
      })

    {:ok, view, _} = live(conn, "/audit/rounds/#{round.id}")
    assert has_element?(view, "#round-audit")
    assert has_element?(view, "#round-verification[data-verified=false]")
  end
end
