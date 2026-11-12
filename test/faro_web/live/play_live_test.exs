defmodule FaroWeb.PlayLiveTest do
  use FaroWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Faro.FaroGame
  alias Faro.FaroGame.{GameSession, Wallet}

  test "disconnected mount writes no game records", %{conn: conn} do
    count = Ash.count!(GameSession)
    conn = get(conn, ~p"/play")
    assert html_response(conn, 200)
    assert Ash.count!(GameSession) == count
  end

  test "repeat bets preserve ledger balance across consecutive deals", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    assert has_element?(view, "#game-table")
    render_click(view, "place_bet", %{"rank" => "1"})
    view |> element("#toggle-keep-bets") |> render_click()

    for _ <- 1..3 do
      view |> element("#deal-turn") |> render_click()
      [wallet] = Ash.read!(Wallet)
      entries = FaroGame.list_ledger_entries_for_wallet!(wallet.id)
      assert wallet.balance_sats == Enum.sum(Enum.map(entries, & &1.amount_sats))
    end
  end

  test "client reseeding preserves commitment, round, and pending funds", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    [round] = Ash.read!(FaroGame.Round)
    [wallet] = Ash.read!(Wallet)
    render_click(view, "place_bet", %{"rank" => "1"})
    view |> element("#regenerate-client-seed") |> render_click()
    [updated] = Ash.read!(FaroGame.Round)
    assert updated.id == round.id
    assert updated.server_seed_hash == round.server_seed_hash
    assert FaroGame.get_wallet!(wallet.id).balance_sats == 1_000_000
    render_click(view, "place_bet", %{"rank" => "1"})
    view |> element("#deal-turn") |> render_click()
    [turn] = FaroGame.list_turns_for_round!(round.id)
    assert length(turn.bets) == 1
    entries = FaroGame.list_ledger_entries_for_wallet!(wallet.id)

    assert Enum.sum(Enum.map(entries, & &1.amount_sats)) ==
             FaroGame.get_wallet!(wallet.id).balance_sats
  end

  test "malformed and out-of-phase events do not crash or create turns", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")

    for {event, params} <- [
          {"place_bet", %{"rank" => "banana"}},
          {"place_bet", %{"rank" => "99"}},
          {"remove_bet", %{"index" => "999"}},
          {"remove_bet", %{"index" => "-1"}},
          {"remove_bet", %{"index" => []}},
          {"set_amount", %{"amount" => %{}}},
          {"ctt_select_card", %{"rank" => "1", "suit" => "not-an-atom"}},
          {"ctt_drop_card", %{"rank" => "1", "suit" => "spades", "slot" => "-1"}},
          {"place_ctt_bet", %{}},
          {"skip_ctt", %{}},
          {"new_round", %{}}
        ] do
      render_click(view, event, params)
      assert has_element?(view, "#game-table")
    end

    [round] = Ash.read!(FaroGame.Round)
    assert FaroGame.list_turns_for_round!(round.id) == []
    assert Ash.count!(FaroGame.Round) == 1
  end

  test "final wager placement and completion are idempotent", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    for _ <- 1..24, do: view |> element("#deal-turn") |> render_click()
    [round] = Ash.read!(FaroGame.Round)
    cards = Enum.take(round.shuffled_deck, -3)
    pool = view |> element("#ctt-card-pool") |> render() |> LazyHTML.from_fragment()

    displayed =
      pool
      |> LazyHTML.query("[data-ctt-card]")
      |> Enum.map(fn node ->
        [rank] = LazyHTML.attribute(node, "data-rank")
        [suit] = LazyHTML.attribute(node, "data-suit")
        {String.to_integer(rank), suit}
      end)

    assert displayed == Enum.sort(Enum.map(cards, &{&1["rank"], &1["suit"]}))

    for {card, index} <- Enum.with_index(cards) do
      render_click(view, "ctt_drop_card", %{
        "rank" => to_string(card["rank"]),
        "suit" => card["suit"],
        "slot" => to_string(index)
      })
    end

    if length(Enum.uniq_by(cards, & &1["rank"])) > 1 do
      render_click(view, "place_ctt_bet", %{})
      render_click(view, "place_ctt_bet", %{})
      render_click(view, "ctt_click_slot", %{"slot" => "0"})
      view |> element("#reveal-final-cards") |> render_click()
    else
      for index <- 0..2, do: render_click(view, "ctt_click_slot", %{"slot" => to_string(index)})
      view |> element("#skip-ctt") |> render_click()
    end

    render_click(view, "deal_turn", %{})
    [wallet] = Ash.read!(Wallet)
    entries = FaroGame.list_ledger_entries_for_wallet!(wallet.id)
    assert wallet.balance_sats == Enum.sum(Enum.map(entries, & &1.amount_sats))
    assert length(FaroGame.list_turns_for_round!(round.id)) == 25
    assert Faro.Audit.get_audit_record_by_round!(round.id).verified
  end

  test "amount controls and seed changes use submitted form values", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/play")
    render_click(view, "toggle_client_seed_edit", %{})
    view |> form("#client-seed-form", %{seed: "  custom seed  "}) |> render_submit()
    [round] = Ash.read!(FaroGame.Round)
    assert round.client_seed == "  custom seed  "
    view |> form("#bet-amount-form", %{amount: "2500"}) |> render_change()
    render_click(view, "place_bet", %{"rank" => "1"})
    view |> element("#deal-turn") |> render_click()
    [turn] = FaroGame.list_turns_for_round!(round.id)
    assert [%{"amount" => 2500}] = turn.bets
  end
end
