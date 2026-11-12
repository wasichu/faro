defmodule FaroWeb.PlayLive do
  use FaroWeb, :live_view

  require Logger

  alias Faro.GameEngine.{Bet, CallTheTurnBet, Card, Deck, Fairness, HighCardBet, Round, Shuffle}
  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer

  @default_bet 1_000

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Play", session_id: nil, wallet: nil)
     |> start_round(1, 1_000_000)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("set_amount", %{"amount" => val}, socket) do
    case parse_integer(val) do
      {:ok, n} when n > 0 and n <= 9_223_372_036_854_775_807 ->
        {:noreply, assign(socket, bet_amount: n)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_copper", _params, socket) do
    {:noreply, assign(socket, copper?: !socket.assigns.copper?)}
  end

  def handle_event("double_amount", _params, socket) do
    {:noreply,
     assign(socket, bet_amount: min(socket.assigns.bet_amount * 2, 9_223_372_036_854_775_807))}
  end

  def handle_event("halve_amount", _params, socket) do
    {:noreply, assign(socket, bet_amount: max(1, div(socket.assigns.bet_amount, 2)))}
  end

  def handle_event("place_bet", %{"rank" => rank_str}, socket) do
    %{balance: balance, bet_amount: amount, copper?: copper?, pending_bets: bets, round: round} =
      socket.assigns

    rank =
      case parse_integer(rank_str) do
        {:ok, rank} -> rank
        _ -> nil
      end

    existing = Enum.find_index(bets, &match?(%Bet{rank: ^rank}, &1))

    cond do
      round.phase != :dealing or not Card.valid_rank?(rank) ->
        {:noreply, socket}

      existing != nil ->
        {removed, new_bets} = List.pop_at(bets, existing)
        {:noreply, assign(socket, pending_bets: new_bets, balance: balance + removed.amount)}

      amount > balance ->
        {:noreply, socket}

      true ->
        bet = %Bet{rank: rank, amount: amount, copper?: copper?}
        {:noreply, assign(socket, pending_bets: bets ++ [bet], balance: balance - amount)}
    end
  end

  def handle_event("place_high_card_bet", _params, socket) do
    %{balance: balance, bet_amount: amount, copper?: copper?, pending_bets: bets, round: round} =
      socket.assigns

    existing = Enum.find_index(bets, &match?(%HighCardBet{}, &1))

    cond do
      round.phase != :dealing ->
        {:noreply, socket}

      existing != nil ->
        {removed, new_bets} = List.pop_at(bets, existing)
        {:noreply, assign(socket, pending_bets: new_bets, balance: balance + removed.amount)}

      amount > balance ->
        {:noreply, socket}

      true ->
        bet = %HighCardBet{amount: amount, copper?: copper?}
        {:noreply, assign(socket, pending_bets: bets ++ [bet], balance: balance - amount)}
    end
  end

  def handle_event("remove_bet", %{"index" => value}, socket) do
    with :dealing <- socket.assigns.round.phase,
         {:ok, index} when index >= 0 <- parse_integer(value),
         %{} = bet <- Enum.at(socket.assigns.pending_bets, index) do
      {:noreply,
       assign(socket,
         pending_bets: List.delete_at(socket.assigns.pending_bets, index),
         balance: socket.assigns.balance + bet.amount
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("place_ctt_bet", _params, socket) do
    %{ctt_slots: [s1, s2, s3], ctt_amount: amount, balance: balance} = socket.assigns

    if editable_ctt?(socket) and s1 != nil and s2 != nil and s3 != nil and
         Enum.sort([s1, s2, s3]) == Enum.sort(socket.assigns.round.deck) and
         length(Enum.uniq_by([s1, s2, s3], & &1.rank)) > 1 and amount > 0 and amount <= balance do
      bet = %CallTheTurnBet{predicted_loser: s1.rank, predicted_winner: s2.rank, amount: amount}
      {:noreply, assign(socket, ctt_placed_bet: bet, balance: balance - amount)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_ctt_bet", _params, socket) do
    case socket.assigns.ctt_placed_bet do
      nil ->
        {:noreply, socket}

      bet ->
        {:noreply,
         assign(socket, ctt_placed_bet: nil, balance: socket.assigns.balance + bet.amount)}
    end
  end

  def handle_event("set_ctt_amount", %{"amount" => val}, socket) do
    case parse_integer(val) do
      {:ok, n} when n >= 0 and n <= 9_223_372_036_854_775_807 ->
        {:noreply, assign(socket, ctt_amount: n)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("halve_ctt_amount", _params, socket) do
    {:noreply, assign(socket, ctt_amount: max(0, div(socket.assigns.ctt_amount, 2)))}
  end

  def handle_event("double_ctt_amount", _params, socket) do
    {:noreply,
     assign(socket, ctt_amount: min(socket.assigns.ctt_amount * 2, 9_223_372_036_854_775_807))}
  end

  def handle_event("ctt_select_card", %{"rank" => rank, "suit" => suit}, socket) do
    with true <- editable_ctt?(socket),
         %Card{} = card <- available_card(socket, rank, suit) do
      selected = if socket.assigns.ctt_selected == card, do: nil, else: card
      {:noreply, assign(socket, ctt_selected: selected)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("skip_ctt", _params, socket) do
    if socket.assigns.round.phase == :call_the_turn and
         Enum.all?(socket.assigns.ctt_slots, &is_nil/1) and socket.assigns.ctt_placed_bet == nil do
      handle_event("deal_turn", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("ctt_click_slot", %{"slot" => value}, socket) do
    with true <- editable_ctt?(socket),
         {:ok, index} when index in 0..2 <- parse_integer(value) do
      slots = socket.assigns.ctt_slots
      card = if Enum.at(slots, index), do: nil, else: socket.assigns.ctt_selected

      {:noreply,
       assign(socket, ctt_slots: List.replace_at(slots, index, card), ctt_selected: nil)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("ctt_drop_card", %{"rank" => rank, "suit" => suit, "slot" => value}, socket) do
    with true <- editable_ctt?(socket),
         {:ok, index} when index in 0..2 <- parse_integer(value),
         %Card{} = card <-
           Enum.find(
             socket.assigns.round.deck,
             &(to_string(&1.rank) == rank and to_string(&1.suit) == suit)
           ) do
      slots =
        socket.assigns.ctt_slots
        |> Enum.map(fn existing -> if existing == card, do: nil, else: existing end)
        |> List.replace_at(index, card)

      {:noreply, assign(socket, ctt_slots: slots, ctt_selected: nil)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("deal_turn", _params, %{assigns: %{round: %{phase: :finished}}} = socket),
    do: {:noreply, socket}

  def handle_event("deal_turn", _params, socket) do
    assigns = socket.assigns

    bets =
      if assigns.round.phase == :call_the_turn,
        do: List.wrap(assigns.ctt_placed_bet),
        else: assigns.pending_bets

    params = %{
      round_id: assigns.db_round_id,
      wallet_id: assigns.wallet.id,
      bets: bets,
      server_seed: assigns.server_seed,
      expected_index: length(assigns.round.turns) + 1
    }

    case FaroGame.deal_game_turn(params) do
      {:ok, result} ->
        {restored_bets, balance} = repeat_bets(result, assigns.keep_bets?)

        slots =
          if result.round.phase == :call_the_turn, do: [nil, nil, nil], else: assigns.ctt_slots

        {:noreply,
         assign(socket,
           round: result.round,
           balance: balance,
           wallet: result.wallet,
           pending_bets: restored_bets,
           last_turn: result.turn,
           last_settlements: result.turn.settlements,
           keep_bets?: assigns.keep_bets? and result.round.phase == :dealing,
           audit: result.audit,
           ctt_slots: slots,
           ctt_selected: nil,
           ctt_placed_bet: nil
         )}

      {:error, _error} ->
        Logger.warning("Game turn transaction failed")

        {:noreply,
         put_flash(
           socket,
           :error,
           "The turn could not be saved. Your bets and balance have not changed."
         )}
    end
  end

  def handle_event("toggle_keep_bets", _params, socket) do
    {:noreply, assign(socket, keep_bets?: !socket.assigns.keep_bets?)}
  end

  def handle_event("new_round", _params, socket) do
    if socket.assigns.round.phase == :finished do
      {:noreply, start_round(socket, socket.assigns.nonce + 1, socket.assigns.balance)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("regenerate_client_seed", _params, socket) do
    if socket.assigns.round.turns == [] do
      {:noreply,
       start_round(socket, socket.assigns.nonce, refunded_balance(socket), reuse_server?: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_client_seed_edit", _params, socket) do
    {:noreply, assign(socket, client_seed_editing?: !socket.assigns.client_seed_editing?)}
  end

  def handle_event("update_client_seed_draft", %{"seed" => seed}, socket)
      when is_binary(seed) and byte_size(seed) <= 256 do
    {:noreply, assign(socket, client_seed_draft: seed)}
  end

  def handle_event("apply_client_seed_draft", %{"seed" => seed}, socket)
      when is_binary(seed) and byte_size(seed) <= 256 do
    handle_event("apply_client_seed_draft", %{}, assign(socket, client_seed_draft: seed))
  end

  def handle_event("apply_client_seed_draft", _params, socket) do
    if socket.assigns.round.turns == [] do
      draft = socket.assigns.client_seed_draft
      seed = if draft == "", do: nil, else: draft

      {:noreply,
       socket
       |> start_round(socket.assigns.nonce, refunded_balance(socket),
         client_seed: seed,
         reuse_server?: true
       )
       |> assign(client_seed_editing?: false, client_seed_draft: "")}
    else
      {:noreply, assign(socket, client_seed_editing?: false)}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
      |> assign(:seed_form, to_form(%{"seed" => assigns.client_seed_draft}))
      |> assign(:bet_form, to_form(%{"amount" => assigns.bet_amount}))
      |> assign(:ctt_form, to_form(%{"amount" => assigns.ctt_amount}))
      |> assign(:board_bets, board_bets(assigns.pending_bets))
      |> assign(:high_card_bet_pending, pending_high_card_bet(assigns.pending_bets))
      |> assign(:turns_dealt, length(assigns.round.turns))
      |> assign(:next_turn, length(assigns.round.turns) + 1)
      |> assign(
        :remaining,
        if(assigns.round.phase == :finished, do: 0, else: length(assigns.round.deck))
      )
      |> assign(:recent_turns, assigns.round.turns |> Enum.take(-5) |> Enum.reverse())
      |> assign(
        :repeat_disabled,
        assigns.pending_bets == [] and not assigns.keep_bets?
      )
      |> assign(
        :ctt_bets,
        if(assigns.last_turn,
          do: Enum.filter(assigns.last_turn.bets, &match?(%CallTheTurnBet{}, &1)),
          else: []
        )
      )
      |> assign(:ctt_available, ctt_available_cards(assigns.round, assigns.ctt_slots))
      |> assign(
        :ctt_deal_enabled,
        ctt_deal_enabled?(assigns.round.phase, assigns.ctt_slots, assigns.ctt_placed_bet)
      )
      |> assign(:ctt_skip_enabled, Enum.all?(assigns.ctt_slots, &is_nil/1))
      |> assign(
        :ctt_place_enabled,
        ctt_place_enabled?(
          assigns.ctt_placed_bet,
          assigns.ctt_slots,
          assigns.ctt_amount,
          assigns.balance
        )
      )
      |> assign(:hock_card, hock_card(assigns.round))
      |> assign(:round_wagered, round_wagered(assigns.round))
      |> assign(:round_net, round_net(assigns.round))

    ~H"""
    <div id="game-table" class="bg-green-950 min-h-full">
      <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 space-y-4">
        <%!-- Header --%>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex flex-wrap items-center gap-3">
            <span class={[
              "rounded border px-3 py-1 text-xs uppercase tracking-widest",
              phase_class(@round.phase)
            ]}>
              {phase_label(@round.phase)}
            </span>
            <span class="text-xs text-stone-400">
              {if @round.phase == :finished,
                do: "Turn #{@turns_dealt} / 25",
                else: "Turn #{@next_turn} / 25"}
            </span>
            <span class="text-xs text-stone-500">{@remaining} cards remain</span>
            <span class="text-xs text-stone-600">·</span>
            <button
              phx-click={JS.show(to: "#glossary-modal")}
              class="text-xs text-stone-500 hover:text-amber-400 transition-colors"
              title="Open glossary"
            >
              Soda
            </button>
            <span class={["font-mono text-sm font-bold", suit_color(@round.soda.suit)]}>
              {rank_label(@round.soda.rank)}{suit_symbol(@round.soda.suit)}
            </span>
            <button
              phx-click={JS.show(to: "#glossary-modal")}
              class="rounded-full border border-stone-600 w-5 h-5 text-[10px] text-stone-500 hover:border-amber-500 hover:text-amber-400 transition-colors flex items-center justify-center"
              title="Glossary"
            >
              ?
            </button>
          </div>
          <div class="flex items-center gap-3">
            <.balance_display balance_sats={@balance} />
          </div>
        </div>

        <%!-- Shuffle Verification + Client Seed (published before play, visible throughout) --%>
        <div class="rounded border border-stone-700 bg-stone-900 divide-y divide-stone-700">
          <div class="flex items-center justify-between px-3 py-1.5 bg-stone-800/60">
            <span class="text-[10px] uppercase tracking-widest text-stone-500">Provably Fair</span>
            <button
              phx-click={JS.show(to: "#glossary-modal")}
              class="text-xs text-amber-400 hover:text-amber-300 transition-colors"
            >
              What are these? →
            </button>
          </div>
          <div class="flex items-start gap-3 px-3 py-2">
            <span class="flex-shrink-0 pt-0.5 text-xs uppercase tracking-widest text-stone-500">
              Shuffle Verification
            </span>
            <span class="break-all font-mono text-[10px] leading-relaxed text-stone-400 flex-1">
              {@commitment}
            </span>
            <%= if @round.turns != [] do %>
              <span class="flex-shrink-0 text-xs text-stone-600">🔒 locked</span>
            <% end %>
          </div>

          <div class="px-3 py-2 space-y-1.5">
            <div class="flex items-start gap-3">
              <span class="flex-shrink-0 pt-0.5 text-xs uppercase tracking-widest text-stone-500">
                Client Seed
              </span>
              <span class="break-all font-mono text-[10px] leading-relaxed text-stone-400 flex-1">
                {@client_seed}
              </span>
              <%= if @round.turns == [] do %>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <button
                    id="regenerate-client-seed"
                    phx-click="regenerate_client_seed"
                    class="text-xs text-stone-500 hover:text-amber-400 transition-colors border border-stone-700 rounded px-2 py-0.5"
                  >
                    Regenerate
                  </button>
                  <button
                    phx-click="toggle_client_seed_edit"
                    class={[
                      "text-xs transition-colors border rounded px-2 py-0.5",
                      if(@client_seed_editing?,
                        do: "border-amber-600 text-amber-400",
                        else: "border-stone-700 text-stone-500 hover:text-amber-400"
                      )
                    ]}
                  >
                    {if @client_seed_editing?, do: "Cancel", else: "Custom"}
                  </button>
                </div>
              <% else %>
                <span class="flex-shrink-0 text-xs text-stone-600">🔒 locked</span>
              <% end %>
            </div>

            <%= if @client_seed_editing? do %>
              <.form
                for={@seed_form}
                id="client-seed-form"
                phx-change="update_client_seed_draft"
                phx-submit="apply_client_seed_draft"
                class="flex items-center gap-2 pt-1 [&_.fieldset]:mb-0"
              >
                <.input
                  field={@seed_form[:seed]}
                  type="text"
                  maxlength="256"
                  placeholder="Enter your own client seed"
                  phx-debounce="200"
                  aria-label="Client seed"
                  class="w-full rounded border border-stone-600 bg-stone-800 px-2 py-1 font-mono text-xs text-stone-100 placeholder-stone-600 focus:border-amber-500 focus:outline-none"
                />
                <button
                  id="apply-client-seed-draft"
                  type="submit"
                  class="rounded border border-amber-600 bg-amber-700 px-3 py-1 text-xs font-semibold text-stone-950 transition-colors hover:bg-amber-600"
                >
                  Apply
                </button>
              </.form>
              <p class="text-[10px] text-stone-600">
                Applying a client seed reshuffles this round using the existing server commitment and refunds pending bets.
              </p>
            <% end %>
          </div>
        </div>

        <%!-- Board (dealing only) or Call the Turn card selection --%>
        <%= if @round.phase == :dealing do %>
          <.faro_board
            bets={@board_bets}
            high_card_bet={@high_card_bet_pending}
            on_rank_click="place_bet"
            on_high_card_click="place_high_card_bet"
          />
        <% end %>
        <%= if @round.phase == :call_the_turn do %>
          <div class="rounded-lg border border-amber-600 bg-amber-950/30 p-4 space-y-5">
            <div>
              <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">
                Call the Turn — Final Three Cards
              </h3>
              <p class="mt-1 text-xs text-stone-400">
                Click a card to select it, then click a slot to place it. Predict the exact order to win 4:1; two of a kind pays 1:1. Leave slots empty to deal without betting.
              </p>
            </div>

            <%!-- Available cards + Predicted Order — side by side on wider viewports --%>
            <div class="flex flex-col gap-6 sm:flex-row" id="ctt-area" phx-hook="CttDragDrop">
              <div class="min-w-0">
                <div class="mb-2 text-xs uppercase tracking-widest text-stone-500">
                  Available Cards
                </div>
                <div id="ctt-card-pool" class="flex flex-wrap gap-3">
                  <%= for card <- @ctt_available do %>
                    <div
                      class={[
                        "cursor-grab transition-all duration-150",
                        if(@ctt_selected == card, do: "-translate-y-2", else: "hover:-translate-y-1")
                      ]}
                      draggable="true"
                      data-ctt-card="true"
                      data-rank={card.rank}
                      data-suit={card.suit}
                      phx-click="ctt_select_card"
                      phx-value-rank={card.rank}
                      phx-value-suit={card.suit}
                    >
                      <div class={[
                        "rounded-lg overflow-hidden",
                        if(@ctt_selected == card, do: "ring-2 ring-amber-400", else: "")
                      ]}>
                        <.playing_card rank={card.rank} suit={card.suit} />
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="min-w-0">
                <div class="mb-2 text-xs uppercase tracking-widest text-stone-500">
                  Predicted Order
                </div>
                <div class="grid grid-cols-3 gap-2 sm:flex sm:gap-4">
                  <%= for {slot_card, idx} <- Enum.with_index(@ctt_slots) do %>
                    <div class="flex flex-col items-center gap-1">
                      <span class="text-xs text-stone-400">
                        {case idx do
                          0 -> "1st · Banker"
                          1 -> "2nd · Player"
                          _ -> "3rd · Hock"
                        end}
                      </span>
                      <div
                        class={[
                          "rounded-lg border-2 cursor-pointer transition-colors overflow-hidden",
                          if(slot_card != nil,
                            do: "border-amber-500",
                            else:
                              "border-dashed border-stone-600 bg-stone-800/50 hover:border-amber-600"
                          )
                        ]}
                        data-ctt-slot={idx}
                        phx-click="ctt_click_slot"
                        phx-value-slot={idx}
                      >
                        <%= if slot_card != nil do %>
                          <.playing_card rank={slot_card.rank} suit={slot_card.suit} />
                        <% else %>
                          <div class="flex h-24 w-16 items-center justify-center">
                            <span class="text-2xl font-bold text-stone-600">{idx + 1}</span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Bet amount + placement --%>
            <div class="flex flex-wrap items-center gap-3">
              <span class="text-xs text-stone-400">Bet Amount</span>
              <div class="flex items-center gap-1.5">
                <button
                  phx-click="halve_ctt_amount"
                  disabled={@ctt_placed_bet != nil}
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  ½
                </button>
                <.form
                  for={@ctt_form}
                  id="ctt-amount-form"
                  phx-change="set_ctt_amount"
                  phx-submit="set_ctt_amount"
                  class="[&_.fieldset]:mb-0"
                >
                  <.input
                    type="number"
                    min="0"
                    field={@ctt_form[:amount]}
                    phx-debounce="blur"
                    aria-label="Bet amount"
                    disabled={@ctt_placed_bet != nil}
                    class="w-24 rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none disabled:opacity-40"
                  />
                </.form>
                <button
                  phx-click="double_ctt_amount"
                  disabled={@ctt_placed_bet != nil}
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  2×
                </button>
              </div>
              <span class="text-xs text-stone-500">sats</span>
              <%= if @ctt_placed_bet == nil and Enum.all?(@ctt_slots, &(&1 != nil)) do %>
                <%= if @ctt_amount == 0 do %>
                  <span class="text-xs text-stone-500">Enter an amount to bet</span>
                <% end %>
                <%= if @ctt_amount > @balance do %>
                  <span class="text-xs text-red-400">Insufficient balance</span>
                <% end %>
              <% end %>
              <%= if @ctt_placed_bet != nil do %>
                <span class="text-xs text-amber-400">Bet placed ✓</span>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Unified betting + action controls --%>
        <%= if @round.phase != :finished do %>
          <div class="rounded-lg border border-stone-700 bg-stone-800 px-4 py-3">
            <%= if @round.phase == :dealing do %>
              <div class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-3">
                <div class="flex items-center">
                  <span class="text-xs uppercase tracking-widest text-stone-400">Bet</span>
                </div>
                <div class="flex flex-wrap items-center gap-3">
                  <button
                    phx-click="toggle_copper"
                    class={[
                      "rounded border px-3 py-1 text-xs font-semibold uppercase tracking-wide transition-colors",
                      if(@copper?,
                        do: "border-orange-600 bg-orange-800 text-orange-200",
                        else: "border-stone-600 bg-stone-700 text-stone-400 hover:border-stone-500"
                      )
                    ]}
                  >
                    Copper
                  </button>
                  <div class="flex items-center gap-1.5">
                    <button
                      phx-click="halve_amount"
                      class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                    >
                      ½
                    </button>
                    <.form
                      for={@bet_form}
                      id="bet-amount-form"
                      phx-change="set_amount"
                      phx-submit="set_amount"
                      class="[&_.fieldset]:mb-0"
                    >
                      <.input
                        type="number"
                        min="1"
                        field={@bet_form[:amount]}
                        phx-debounce="300"
                        aria-label="Bet amount"
                        class="w-24 rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                      />
                    </.form>
                    <button
                      phx-click="double_amount"
                      class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                    >
                      2×
                    </button>
                    <span class="text-xs text-stone-500">sats</span>
                  </div>
                </div>
                <div></div>
                <div class="flex flex-wrap items-center gap-3">
                  <button
                    id="toggle-keep-bets"
                    phx-click="toggle_keep_bets"
                    disabled={@repeat_disabled}
                    class={[
                      "rounded border px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                      cond do
                        @repeat_disabled ->
                          "border-stone-700 bg-stone-800 text-stone-600 cursor-not-allowed"

                        @keep_bets? ->
                          "border-amber-600 bg-amber-900/60 text-amber-300 hover:bg-amber-900"

                        true ->
                          "border-stone-600 bg-stone-700 text-stone-400 hover:border-stone-500 hover:text-stone-200"
                      end
                    ]}
                  >
                    {if @keep_bets?, do: "Repeating Bets ✓", else: "Repeat Bets"}
                  </button>
                  <button
                    id="deal-turn"
                    phx-click="deal_turn"
                    disabled={not @ctt_deal_enabled}
                    class={[
                      "rounded border px-4 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                      if(@ctt_deal_enabled,
                        do: "border-amber-600 bg-amber-700 text-stone-950 hover:bg-amber-600",
                        else:
                          "border-stone-700 bg-stone-800 text-stone-500 cursor-not-allowed opacity-50"
                      )
                    ]}
                  >
                    Deal Turn
                  </button>
                  <%= if @last_settlements != [] do %>
                    <% last_net = Enum.sum(Enum.map(@last_settlements, & &1.net)) %>
                    <div class={[
                      "min-h-5 font-mono text-sm font-semibold",
                      cond do
                        last_net > 0 -> "text-green-400"
                        last_net < 0 -> "text-red-400"
                        true -> "text-stone-500"
                      end
                    ]}>
                      {if last_net == 0,
                        do: "push",
                        else: "#{if last_net > 0, do: "+"}#{format_sats(last_net)}"}
                    </div>
                  <% else %>
                    <div class="min-h-5" />
                  <% end %>
                </div>
              </div>
            <% end %>
            <%= if @round.phase == :call_the_turn do %>
              <div class="flex flex-wrap items-center justify-end gap-3">
                <button
                  id="skip-ctt"
                  phx-click="skip_ctt"
                  disabled={not @ctt_skip_enabled}
                  class={[
                    "rounded border px-4 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                    if(@ctt_skip_enabled,
                      do:
                        "border-stone-600 bg-stone-700 text-stone-400 hover:border-stone-500 hover:text-stone-200",
                      else:
                        "border-stone-700 bg-stone-800 text-stone-600 cursor-not-allowed opacity-50"
                    )
                  ]}
                >
                  Skip Final Bet
                </button>
                <button
                  id="place-ctt-bet"
                  phx-click="place_ctt_bet"
                  disabled={not @ctt_place_enabled}
                  class={[
                    "rounded border px-4 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                    if(@ctt_place_enabled,
                      do: "border-amber-600 bg-amber-700 text-stone-950 hover:bg-amber-600",
                      else:
                        "border-stone-700 bg-stone-800 text-stone-500 cursor-not-allowed opacity-50"
                    )
                  ]}
                >
                  Place Final Bet
                </button>
                <button
                  id="reveal-final-cards"
                  phx-click="deal_turn"
                  disabled={not @ctt_deal_enabled}
                  class={[
                    "rounded border px-4 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                    if(@ctt_deal_enabled,
                      do: "border-amber-600 bg-amber-700 text-stone-950 hover:bg-amber-600",
                      else:
                        "border-stone-700 bg-stone-800 text-stone-500 cursor-not-allowed opacity-50"
                    )
                  ]}
                >
                  Reveal Final Cards
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Last turn + recent turns --%>
        <div class="flex flex-col rounded-lg border border-stone-700 bg-stone-800 divide-y divide-stone-700 sm:flex-row sm:divide-x sm:divide-y-0">
          <div class="p-4 sm:flex-shrink-0">
            <.current_turn_display
              banker_card={if @last_turn, do: @last_turn.loser}
              player_card={if @last_turn, do: @last_turn.winner}
              hock_card={@hock_card}
              turn_number={if @last_turn, do: @last_turn.index}
              split?={@last_turn != nil and @last_turn.split? and @round.phase != :finished}
            />
          </div>
          <div class="p-4 flex-1 min-w-0">
            <.recent_turns_list turns={@recent_turns} hock_card={@hock_card} />
          </div>
        </div>

        <%!-- Round Complete --%>
        <%= if @round.phase == :finished do %>
          <div class="rounded-lg border border-amber-700/50 bg-stone-900 p-4 space-y-3">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-bold uppercase tracking-widest text-amber-400">
                Round Complete
              </h3>
              <div class="flex items-center gap-3">
                <%= if @db_round_id do %>
                  <.link
                    href={~p"/audit/rounds/#{@db_round_id}"}
                    target="_blank"
                    class="inline-flex items-center justify-center rounded border border-stone-600 px-4 py-2 text-xs font-semibold uppercase tracking-widest text-stone-300 transition-colors hover:border-amber-600 hover:text-amber-400"
                  >
                    Audit Round
                  </.link>
                <% end %>
                <button
                  id="new-round"
                  phx-click="new_round"
                  class="rounded border border-amber-600 bg-amber-600 px-4 py-2 text-xs font-semibold uppercase tracking-widest text-stone-950 transition-colors hover:bg-amber-500"
                >
                  New Round
                </button>
              </div>
            </div>
            <div class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-stone-300">
              <span>
                Final balance:
                <span class="font-mono font-semibold text-amber-400">{format_sats(@balance)}</span>
                sats
              </span>
              <%= if @round_wagered > 0 do %>
                <span>
                  Wagered:
                  <span class="font-mono font-semibold text-stone-200">
                    {format_sats(@round_wagered)}
                  </span>
                  sats
                </span>
                <span>
                  Net:
                  <span class={[
                    "font-mono font-semibold",
                    cond do
                      @round_net > 0 -> "text-green-400"
                      @round_net < 0 -> "text-red-400"
                      true -> "text-stone-400"
                    end
                  ]}>
                    {if @round_net > 0,
                      do: "+#{format_sats(@round_net)}",
                      else: format_sats(@round_net)}
                  </span>
                  sats
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Combined bets + settlements --%>
        <%= if @pending_bets != [] or @last_settlements != [] or @ctt_placed_bet != nil do %>
          <div class="rounded-lg border border-stone-700 bg-stone-800 px-4 py-3 space-y-2">
            <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">Bets</h3>

            <%= if @last_settlements != [] do %>
              <%!-- Post-deal: each settled bet with outcome below it --%>
              <%!-- Restored bets for next turn (shown first) --%>
              <%= if @pending_bets != [] and @round.phase == :dealing do %>
                <div class="space-y-1.5">
                  <div class="text-[10px] uppercase tracking-widest text-stone-500">Next Turn</div>
                  <ul class="space-y-1.5">
                    <%= for {bet, idx} <- Enum.with_index(@pending_bets) do %>
                      <li class="flex items-center justify-between text-sm">
                        <span class="text-stone-300">{pending_bet_label(bet)}</span>
                        <div class="flex items-center gap-3">
                          <span class="font-mono text-amber-400">{format_sats(bet.amount)} sats</span>
                          <button
                            phx-click="remove_bet"
                            phx-value-index={idx}
                            class="text-xs text-stone-500 transition-colors hover:text-red-400"
                          >
                            ✕
                          </button>
                        </div>
                      </li>
                    <% end %>
                  </ul>
                </div>
                <div class="border-t border-stone-700"></div>
              <% end %>
              <%!-- CTT placed bet --%>
              <%= if @ctt_placed_bet do %>
                <div class="space-y-1.5">
                  <div class="text-[10px] uppercase tracking-widest text-stone-500">
                    Call the Turn
                  </div>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-stone-300">{pending_bet_label(@ctt_placed_bet)}</span>
                    <div class="flex items-center gap-3">
                      <span class="font-mono text-amber-400">
                        {format_sats(@ctt_placed_bet.amount)} sats
                      </span>
                      <button
                        phx-click="remove_ctt_bet"
                        class="text-xs text-stone-500 transition-colors hover:text-red-400"
                      >
                        ✕
                      </button>
                    </div>
                  </div>
                </div>
                <div class="border-t border-stone-700"></div>
              <% end %>
              <%!-- Last turn settlements --%>
              <div class="text-[10px] uppercase tracking-widest text-stone-500">Last Turn</div>
              <ul class="divide-y divide-stone-700/50">
                <%= for s <- @last_settlements do %>
                  <li class="py-2 flex items-start justify-between gap-3 text-sm">
                    <div class="space-y-0.5">
                      <div class="text-stone-300">{pending_bet_label(s.bet)}</div>
                      <div class="flex items-center gap-2">
                        <span class={["text-xs font-semibold", outcome_text_class(s.outcome)]}>
                          {outcome_word(s.outcome)}
                        </span>
                        <span class={["font-mono text-xs", outcome_text_class(s.outcome)]}>
                          {outcome_net_label(s.outcome, s.net)}
                        </span>
                      </div>
                    </div>
                    <span class="font-mono text-stone-500 text-xs flex-shrink-0 pt-0.5">
                      {format_sats(s.bet.amount)} sats
                    </span>
                  </li>
                <% end %>
              </ul>
            <% else %>
              <%!-- Pre-deal: pending bets only --%>
              <ul class="space-y-1.5">
                <%= for {bet, idx} <- Enum.with_index(@pending_bets) do %>
                  <li class="flex items-center justify-between text-sm">
                    <span class="text-stone-300">{pending_bet_label(bet)}</span>
                    <div class="flex items-center gap-3">
                      <span class="font-mono text-amber-400">{format_sats(bet.amount)} sats</span>
                      <button
                        phx-click="remove_bet"
                        phx-value-index={idx}
                        class="text-xs text-stone-500 transition-colors hover:text-red-400"
                      >
                        ✕
                      </button>
                    </div>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        <% end %>

        <%!-- Call the Turn result breakdown --%>
        <%= if @round.phase == :finished and @ctt_bets != [] do %>
          <div class="rounded-lg border border-amber-600/40 bg-stone-900 p-4 space-y-4">
            <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">
              Call the Turn — Result
            </h3>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <div class="mb-2 text-xs text-stone-500">Your Prediction</div>
                <div class="flex flex-wrap gap-2 sm:gap-3">
                  <%= for {slot_card, idx} <- Enum.with_index(@ctt_slots) do %>
                    <%= if slot_card do %>
                      <.playing_card
                        rank={slot_card.rank}
                        suit={slot_card.suit}
                        label={
                          case idx do
                            0 -> "Banker"
                            1 -> "Player"
                            _ -> "Hock"
                          end
                        }
                      />
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div>
                <div class="mb-2 text-xs text-stone-500">Actual Order</div>
                <div class="flex flex-wrap gap-2 sm:gap-3">
                  <.playing_card
                    rank={@last_turn.loser.rank}
                    suit={@last_turn.loser.suit}
                    label="Banker"
                  />
                  <.playing_card
                    rank={@last_turn.winner.rank}
                    suit={@last_turn.winner.suit}
                    label="Player"
                  />
                  <%= if @hock_card do %>
                    <.playing_card rank={@hock_card.rank} suit={@hock_card.suit} label="Hock" />
                  <% end %>
                </div>
              </div>
            </div>

            <ul class="space-y-1">
              <%= for bet <- @ctt_bets do %>
                <li class="flex items-center gap-3 text-sm">
                  <%= if bet.predicted_loser == @last_turn.loser.rank and
                          bet.predicted_winner == @last_turn.winner.rank do %>
                    <span class="text-green-400 font-semibold">✓ Correct</span>
                  <% else %>
                    <span class="text-red-400 font-semibold">✗ Wrong order</span>
                  <% end %>
                  <span class="text-xs text-stone-500">
                    Predicted Banker {rank_label(bet.predicted_loser)} → Player {rank_label(
                      bet.predicted_winner
                    )}
                  </span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <.casekeeper_display seen={@round.casekeeper.seen} />

        <%= if @audit do %>
          <.audit_panel audit={@audit} />
        <% end %>
      </div>
    </div>

    <%!-- Glossary modal --%>
    <div id="glossary-modal" class="hidden fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        class="absolute inset-0 bg-stone-950/80 backdrop-blur-sm"
        phx-click={JS.hide(to: "#glossary-modal")}
      >
      </div>
      <div class="relative w-full max-w-lg rounded-lg border border-stone-700 bg-stone-900 shadow-2xl flex flex-col max-h-[80vh]">
        <div class="flex items-center justify-between border-b border-stone-700 px-5 py-4 flex-shrink-0">
          <h2 class="font-serif text-lg font-semibold text-amber-400">Glossary</h2>
          <button
            phx-click={JS.hide(to: "#glossary-modal")}
            class="text-stone-500 hover:text-stone-200 transition-colors text-lg leading-none"
          >
            ✕
          </button>
        </div>
        <div class="overflow-y-auto px-5 py-4 space-y-5 text-sm">
          <.glossary_entry term="Shuffle Verification">
            A SHA-256 hash of the server seed, published before any cards are dealt. After the round the server reveals its seed — you can hash it yourself to confirm it matches, proving the shuffle was pre-committed and never changed.
          </.glossary_entry>
          <.glossary_entry term="Client Seed">
            Your contribution to the shuffle. You can type any value you like before the first card is dealt — the box shows your raw input. What actually drives the card order is the Shuffle Seed, a value derived by running your seed through HMAC-SHA256 together with the server seed and a round counter (nonce). So what you type and what the shuffle uses are related but not the same number. The nonce is not secret — it starts at 1 and increments with each new round, and is shown alongside the other audit values at the end of every round. Because both you and the server contribute, neither party alone controls the outcome.
          </.glossary_entry>
          <.glossary_entry term="Server Seed">
            A secret 32-byte random value generated by the server before the round begins. Kept hidden during play, then revealed at the end so the shuffle can be independently verified.
          </.glossary_entry>
          <.glossary_entry term="Shuffle Seed">
            The 32-byte value derived from server seed, client seed, and nonce using HMAC-SHA256. It directly drives the Fisher-Yates shuffle algorithm to produce the deck order.
          </.glossary_entry>
          <.glossary_entry term="Nonce">
            A round counter that increments with each new round. Ensures a unique shuffle even if the same client seed is reused across rounds.
          </.glossary_entry>
          <.glossary_entry term="Soda">
            The first card burned from the top of the deck at the start of each round. Shown face-up and counted in the casekeeper, but no bets are settled on the soda card.
          </.glossary_entry>
          <.glossary_entry term="Hock">
            The last card remaining after all 25 turns are dealt. It is revealed but never dealt — no bets settle on the hock.
          </.glossary_entry>
          <.glossary_entry term="Doublet (Split)">
            When both cards in a turn share the same rank. Any bet on that rank loses half its stake to the house; the other half is returned. The copper flag does not affect a split.
          </.glossary_entry>
          <.glossary_entry term="Copper">
            A marker placed on a bet to reverse it. A coppered bet wins when its rank appears as the banker card and loses when it appears as the player card — the opposite of a plain bet.
          </.glossary_entry>
          <.glossary_entry term="Call the Turn">
            The final bet, placed when exactly three cards remain. Players predict the exact order of banker and player cards. Correct prediction on three distinct ranks pays 4:1; a cat-hop (two of a kind) pays 1:1.
          </.glossary_entry>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :term, :string, required: true

  defp glossary_entry(assigns) do
    ~H"""
    <div class="space-y-1">
      <dt class="font-semibold text-stone-200">{@term}</dt>
      <dd class="text-stone-400 leading-relaxed">{render_slot(@inner_block)}</dd>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp start_round(socket, nonce, balance, opts \\ []) do
    server_seed =
      if Keyword.get(opts, :reuse_server?, false),
        do: socket.assigns.server_seed,
        else: :crypto.strong_rand_bytes(32)

    commitment = Fairness.commit_server_seed(server_seed)

    client_seed =
      Keyword.get_lazy(opts, :client_seed, fn ->
        :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      end) || :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
    shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)
    round = Round.new(shuffled_deck)

    persistence = persist_round_start(socket, shuffled_deck, commitment, client_seed, nonce, opts)

    socket =
      assign(socket,
        balance: balance,
        round: round,
        server_seed: server_seed,
        commitment: commitment,
        client_seed: client_seed,
        nonce: nonce,
        shuffled_deck: shuffled_deck,
        db_round_id: nil,
        pending_bets: [],
        last_turn: nil,
        last_settlements: [],
        bet_amount: @default_bet,
        copper?: false,
        keep_bets?: Map.get(socket.assigns, :keep_bets?, false),
        ctt_slots: [nil, nil, nil],
        ctt_selected: nil,
        ctt_amount: @default_bet,
        ctt_placed_bet: nil,
        audit: nil,
        client_seed_editing?: false,
        client_seed_draft: ""
      )

    case persistence do
      {:ok, state} ->
        assign(socket, state)

      {:error, _} ->
        Logger.warning("Game startup transaction failed")

        socket
        |> put_flash(:error, "Unable to start a saved game. Please try again.")
        |> push_navigate(to: ~p"/")
    end
  end

  defp persist_round_start(socket, deck, commitment, client_seed, nonce, opts) do
    attrs = %{
      nonce: nonce,
      client_seed: client_seed,
      server_seed_hash: commitment,
      algorithm_version: Fairness.algorithm_version(),
      soda_rank: hd(deck).rank,
      soda_suit: to_string(hd(deck).suit),
      status: :dealing,
      shuffled_deck: Serializer.encode_deck(deck)
    }

    cond do
      not connected?(socket) ->
        {:ok, %{db_round_id: nil}}

      socket.assigns.wallet == nil ->
        with {:ok, game} <- FaroGame.start_game(attrs) do
          {:ok, %{session_id: game.session.id, wallet: game.wallet, db_round_id: game.round.id}}
        end

      Keyword.get(opts, :reuse_server?, false) ->
        with {:ok, round} <- FaroGame.get_round(socket.assigns.db_round_id),
             {:ok, round} <- FaroGame.update_round(round, attrs) do
          {:ok, %{db_round_id: round.id}}
        end

      true ->
        with {:ok, round} <-
               FaroGame.create_round(Map.put(attrs, :game_session_id, socket.assigns.session_id)) do
          {:ok, %{db_round_id: round.id}}
        end
    end
  end

  defp repeat_bets(%{round: %{phase: :dealing}, turn: turn, wallet: wallet}, true) do
    {bets, balance} =
      Enum.reduce(turn.bets, {[], wallet.balance_sats}, fn bet, {bets, balance} ->
        if bet.amount <= balance, do: {[bet | bets], balance - bet.amount}, else: {bets, balance}
      end)

    {Enum.reverse(bets), balance}
  end

  defp repeat_bets(result, _keep?), do: {[], result.wallet.balance_sats}

  defp refunded_balance(socket) do
    socket.assigns.balance + Enum.sum(Enum.map(socket.assigns.pending_bets, & &1.amount))
  end

  defp editable_ctt?(socket) do
    socket.assigns.round.phase == :call_the_turn and socket.assigns.ctt_placed_bet == nil
  end

  defp available_card(socket, rank, suit) do
    Enum.find(
      ctt_available_cards(socket.assigns.round, socket.assigns.ctt_slots),
      &(to_string(&1.rank) == rank and to_string(&1.suit) == suit)
    )
  end

  defp parse_integer(value) when is_binary(value) and byte_size(value) <= 32 do
    case Integer.parse(value) do
      {number, ""} -> {:ok, number}
      _ -> :error
    end
  end

  defp parse_integer(_), do: :error

  defp ctt_available_cards(round, slots) do
    if round.phase == :call_the_turn do
      placed = MapSet.new(Enum.reject(slots, &is_nil/1))

      round.deck
      |> Enum.reject(&MapSet.member?(placed, &1))
      |> Enum.sort_by(&{&1.rank, &1.suit})
    else
      []
    end
  end

  defp ctt_deal_enabled?(:call_the_turn, slots, placed_bet) do
    Enum.all?(slots, &(&1 != nil)) and placed_bet != nil
  end

  defp ctt_deal_enabled?(_, _slots, _placed_bet), do: true

  defp ctt_place_enabled?(nil, slots, amount, balance) do
    Enum.all?(slots, &(&1 != nil)) and length(Enum.uniq_by(slots, & &1.rank)) > 1 and amount > 0 and
      amount <= balance
  end

  defp ctt_place_enabled?(_placed_bet, _slots, _amount, _balance), do: false

  defp hock_card(round) do
    if round.phase == :finished and round.deck != [], do: hd(round.deck)
  end

  defp round_wagered(round) do
    Enum.sum(for turn <- round.turns, s <- turn.settlements, do: s.bet.amount)
  end

  defp round_net(round) do
    Enum.sum(for turn <- round.turns, s <- turn.settlements, do: s.net)
  end

  defp board_bets(pending_bets) do
    pending_bets
    |> Enum.filter(&match?(%Bet{}, &1))
    |> Enum.reduce(%{}, fn %Bet{rank: rank, amount: amount, copper?: copper?}, acc ->
      Map.update(acc, rank, %{amount: amount, copper?: copper?}, fn ex ->
        %{ex | amount: ex.amount + amount, copper?: copper?}
      end)
    end)
  end

  defp pending_high_card_bet(pending_bets) do
    Enum.find(pending_bets, &match?(%HighCardBet{}, &1))
  end

  defp pending_bet_label(%Bet{rank: rank, copper?: true}),
    do: "#{rank_label(rank)} (copper)"

  defp pending_bet_label(%Bet{rank: rank}), do: rank_label(rank)
  defp pending_bet_label(%HighCardBet{copper?: true}), do: "High Card (copper)"
  defp pending_bet_label(%HighCardBet{}), do: "High Card"

  defp pending_bet_label(%CallTheTurnBet{predicted_loser: l, predicted_winner: w}),
    do: "Call the Turn: Banker #{rank_label(l)} → Player #{rank_label(w)}"

  defp outcome_word(:win), do: "Won"
  defp outcome_word(:loss), do: "Lost"
  defp outcome_word(:push), do: "Push"
  defp outcome_word(:split), do: "Split"
  defp outcome_word(:void), do: "Void"

  defp outcome_text_class(:win), do: "text-green-400"
  defp outcome_text_class(:loss), do: "text-red-400"
  defp outcome_text_class(:push), do: "text-stone-500"
  defp outcome_text_class(:split), do: "text-amber-400"
  defp outcome_text_class(:void), do: "text-stone-500"

  defp outcome_net_label(:win, net), do: "+#{format_sats(net)}"
  defp outcome_net_label(:loss, net), do: "#{format_sats(net)}"
  defp outcome_net_label(:push, _net), do: "returned"
  defp outcome_net_label(:split, net), do: format_sats(net)
  defp outcome_net_label(:void, _net), do: "returned"

  defp rank_label(1), do: "A"
  defp rank_label(11), do: "J"
  defp rank_label(12), do: "Q"
  defp rank_label(13), do: "K"
  defp rank_label(n), do: Integer.to_string(n)

  defp suit_symbol(:spades), do: "♠"
  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"

  defp suit_color(:hearts), do: "text-red-500"
  defp suit_color(:diamonds), do: "text-red-500"
  defp suit_color(:spades), do: "text-stone-200"
  defp suit_color(:clubs), do: "text-stone-200"

  defp phase_label(:dealing), do: "Dealing"
  defp phase_label(:call_the_turn), do: "Call the Turn"
  defp phase_label(:finished), do: "Finished"

  defp phase_class(:dealing), do: "border-stone-700 bg-stone-800 text-stone-400"
  defp phase_class(:call_the_turn), do: "border-amber-600 bg-amber-900 text-amber-300"
  defp phase_class(:finished), do: "border-green-700 bg-green-900 text-green-300"
end
