defmodule FaroWeb.PlayLive do
  use FaroWeb, :live_view

  require Logger

  alias Faro.GameEngine.{Audit, Bet, CallTheTurnBet, Card, Deck, Fairness, HighCardBet, Round, Shuffle}
  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer
  alias Faro.FaroGame.Wallet
  alias Faro.Audit.Record, as: AuditRecord

  @starting_balance 1_000_000
  @default_bet 1_000

  def mount(_params, _session, socket) do
    session_id =
      case FaroGame.create_session(%{}) do
        {:ok, session} -> session.id
        {:error, e} -> Logger.warning("GameSession creation failed: #{inspect(e)}"); nil
      end

    {wallet, balance} =
      case Wallet.create_with_topup(%{game_session_id: session_id}) do
        {:ok, w} -> {w, w.balance_sats}
        {:error, e} -> Logger.warning("Wallet creation failed: #{inspect(e)}"); {nil, @starting_balance}
      end

    {:ok,
     socket
     |> assign(page_title: "Play", session_id: session_id, wallet: wallet)
     |> start_round(1, balance)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("set_amount", %{"amount" => val}, socket) do
    case Integer.parse(val) do
      {n, ""} when n > 0 -> {:noreply, assign(socket, bet_amount: n)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_copper", _params, socket) do
    {:noreply, assign(socket, copper?: !socket.assigns.copper?)}
  end

  def handle_event("double_amount", _params, socket) do
    {:noreply, assign(socket, bet_amount: socket.assigns.bet_amount * 2)}
  end

  def handle_event("halve_amount", _params, socket) do
    {:noreply, assign(socket, bet_amount: max(1, div(socket.assigns.bet_amount, 2)))}
  end

  def handle_event("place_bet", %{"rank" => rank_str}, socket) do
    %{balance: balance, bet_amount: amount, copper?: copper?, pending_bets: bets, round: round} =
      socket.assigns

    rank = String.to_integer(rank_str)
    existing = Enum.find_index(bets, &match?(%Bet{rank: ^rank}, &1))

    cond do
      round.phase != :dealing ->
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

  def handle_event("remove_bet", %{"index" => idx_str}, socket) do
    if socket.assigns.round.phase != :dealing do
      {:noreply, socket}
    else
      idx = String.to_integer(idx_str)
      {bet, new_bets} = List.pop_at(socket.assigns.pending_bets, idx)
      {:noreply, assign(socket, pending_bets: new_bets, balance: socket.assigns.balance + bet.amount)}
    end
  end

  def handle_event("set_ctt_amount", %{"amount" => val}, socket) do
    case Integer.parse(val) do
      {n, ""} when n >= 0 -> {:noreply, assign(socket, ctt_amount: n)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("halve_ctt_amount", _params, socket) do
    {:noreply, assign(socket, ctt_amount: max(0, div(socket.assigns.ctt_amount, 2)))}
  end

  def handle_event("double_ctt_amount", _params, socket) do
    {:noreply, assign(socket, ctt_amount: socket.assigns.ctt_amount * 2)}
  end

  def handle_event("ctt_select_card", %{"rank" => rank_str, "suit" => suit_str}, socket) do
    %{ctt_selected: selected} = socket.assigns
    rank = String.to_integer(rank_str)
    suit = String.to_existing_atom(suit_str)
    card = %Card{rank: rank, suit: suit}
    new_selected = if selected == card, do: nil, else: card
    {:noreply, assign(socket, ctt_selected: new_selected)}
  end

  def handle_event("skip_ctt", _params, socket) do
    handle_event("deal_turn", %{}, assign(socket, ctt_slots: [nil, nil, nil]))
  end

  def handle_event("ctt_click_slot", %{"slot" => idx_str}, socket) do
    %{ctt_selected: selected, ctt_slots: slots} = socket.assigns
    idx = String.to_integer(idx_str)
    current = Enum.at(slots, idx)

    cond do
      current != nil ->
        {:noreply, assign(socket, ctt_slots: List.replace_at(slots, idx, nil))}

      selected != nil ->
        {:noreply,
         assign(socket, ctt_slots: List.replace_at(slots, idx, selected), ctt_selected: nil)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("deal_turn", _params, socket) do
    %{
      round: round,
      pending_bets: bets,
      keep_bets?: keep_bets?,
      shuffled_deck: shuffled_deck,
      server_seed: server_seed,
      commitment: commitment,
      client_seed: client_seed,
      nonce: nonce,
      balance: balance,
      ctt_slots: ctt_slots,
      ctt_amount: ctt_amount
    } = socket.assigns

    # For CTT phase: build bet from slots atomically at deal time
    {bets_to_deal, pre_deal_balance} =
      if round.phase == :call_the_turn do
        [s1, s2, s3] = ctt_slots

        if s1 != nil and s2 != nil and s3 != nil and ctt_amount > 0 and ctt_amount <= balance do
          ctt_bet = %CallTheTurnBet{
            predicted_loser: s1.rank,
            predicted_winner: s2.rank,
            amount: ctt_amount
          }

          {[ctt_bet], balance - ctt_amount}
        else
          {[], balance}
        end
      else
        {bets, balance}
      end

    {completed_turn, new_round} = Round.deal_turn(round, bets_to_deal)

    delta =
      Enum.reduce(completed_turn.settlements, 0, fn s, acc ->
        acc + s.bet.amount + s.net
      end)

    post_deal_balance = pre_deal_balance + delta

    {restored_bets, final_balance, keep_bets?} =
      if keep_bets? and new_round.phase == :dealing do
        {bets, bal} =
          Enum.reduce(completed_turn.bets, {[], post_deal_balance}, fn bet, {acc, bal} ->
            if match?(%CallTheTurnBet{}, bet) or bet.amount > bal do
              {acc, bal}
            else
              {acc ++ [bet], bal - bet.amount}
            end
          end)

        {bets, bal, true}
      else
        {[], post_deal_balance, false}
      end

    audit =
      if new_round.phase == :finished do
        Audit.from_round(new_round, commitment, server_seed, client_seed, nonce, shuffled_deck)
        |> Audit.verify_full()
      end

    # Persistence — fire-and-forget; errors are logged but never crash the LiveView
    db_round_id = socket.assigns[:db_round_id]
    persist_turn(db_round_id, completed_turn)

    if new_round.phase == :call_the_turn and round.phase == :dealing do
      update_round_phase(db_round_id, :call_the_turn)
    end

    if new_round.phase == :finished do
      persist_round_complete(db_round_id, server_seed, audit)
    end

    updated_wallet =
      record_wallet_turn(socket.assigns[:wallet], completed_turn, final_balance,
        round_id: db_round_id,
        turn_index: completed_turn.index
      )

    # Reset CTT state when entering CTT phase; preserve slots after CTT deal (for result display)
    {new_ctt_slots, new_ctt_selected} =
      if new_round.phase == :call_the_turn,
        do: {[nil, nil, nil], nil},
        else: {ctt_slots, socket.assigns.ctt_selected}

    {:noreply,
     assign(socket,
       round: new_round,
       balance: final_balance,
       wallet: updated_wallet,
       pending_bets: restored_bets,
       last_turn: completed_turn,
       last_settlements: completed_turn.settlements,
       keep_bets?: keep_bets?,
       audit: audit,
       ctt_slots: new_ctt_slots,
       ctt_selected: new_ctt_selected
     )}
  end

  def handle_event("toggle_keep_bets", _params, socket) do
    {:noreply, assign(socket, keep_bets?: !socket.assigns.keep_bets?)}
  end

  def handle_event("new_round", _params, socket) do
    {:noreply, start_round(socket, socket.assigns.nonce + 1, socket.assigns.balance)}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
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
        ctt_deal_enabled?(assigns.round.phase, assigns.ctt_slots, assigns.ctt_amount, assigns.balance)
      )
      |> assign(:hock_card, hock_card(assigns.round))
      |> assign(:round_wagered, round_wagered(assigns.round))
      |> assign(:round_net, round_net(assigns.round))

    ~H"""
    <div class="bg-green-950 min-h-full">
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
            <span class="text-xs text-stone-500">Soda</span>
            <span class={["font-mono text-sm font-bold", suit_color(@round.soda.suit)]}>
              {rank_label(@round.soda.rank)}{suit_symbol(@round.soda.suit)}
            </span>
          </div>
          <.balance_display balance_sats={@balance} />
        </div>

        <%!-- Commitment (published before play, visible throughout) --%>
        <div class="flex items-start gap-3 rounded border border-stone-700 bg-stone-900 px-3 py-2">
          <span class="flex-shrink-0 pt-0.5 text-xs uppercase tracking-widest text-stone-500">
            Commitment
          </span>
          <span class="break-all font-mono text-[10px] leading-relaxed text-stone-400">
            {@commitment}
          </span>
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

            <%!-- Available cards --%>
            <div>
              <div class="mb-2 text-xs uppercase tracking-widest text-stone-500">Available Cards</div>
              <div class="flex gap-3">
                <%= for card <- @ctt_available do %>
                  <div
                    class={[
                      "cursor-pointer transition-all duration-150",
                      if(@ctt_selected == card, do: "-translate-y-2", else: "hover:-translate-y-1")
                    ]}
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

            <%!-- Prediction slots --%>
            <div>
              <div class="mb-2 text-xs uppercase tracking-widest text-stone-500">Predicted Order</div>
              <div class="flex gap-4">
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
                      phx-click="ctt_click_slot"
                      phx-value-slot={idx}
                    >
                      <%= if slot_card != nil do %>
                        <.playing_card rank={slot_card.rank} suit={slot_card.suit} />
                      <% else %>
                        <div class="h-24 w-16 flex items-center justify-center">
                          <span class="text-2xl font-bold text-stone-600">{idx + 1}</span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Bet amount --%>
            <div class="flex flex-wrap items-center gap-3">
              <span class="text-xs text-stone-400">Bet Amount</span>
              <div class="flex items-center gap-1.5">
                <button
                  phx-click="halve_ctt_amount"
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                >
                  ½
                </button>
                <input
                  type="number"
                  min="0"
                  value={@ctt_amount}
                  phx-change="set_ctt_amount"
                  phx-debounce="300"
                  name="amount"
                  class="w-24 rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                />
                <button
                  phx-click="double_ctt_amount"
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                >
                  2×
                </button>
              </div>
              <span class="text-xs text-stone-500">sats</span>
              <%= if Enum.all?(@ctt_slots, &(&1 != nil)) and @ctt_amount == 0 do %>
                <span class="text-xs text-stone-500">No bet — predict only</span>
              <% end %>
              <%= if Enum.all?(@ctt_slots, &(&1 != nil)) and @ctt_amount > @balance do %>
                <span class="text-xs text-red-400">Insufficient balance</span>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Unified betting + action controls --%>
        <%= if @round.phase != :finished do %>
          <div class="flex flex-wrap items-center gap-3 rounded-lg border border-stone-700 bg-stone-800 px-4 py-3">
            <%= if @round.phase == :dealing do %>
              <span class="text-xs uppercase tracking-widest text-stone-400">Bet</span>
              <div class="flex items-center gap-1.5">
                <button
                  phx-click="halve_amount"
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                >
                  ½
                </button>
                <input
                  type="number"
                  min="1"
                  value={@bet_amount}
                  phx-change="set_amount"
                  phx-debounce="300"
                  name="amount"
                  class="w-24 rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                />
                <button
                  phx-click="double_amount"
                  class="rounded border border-stone-600 bg-stone-700 px-2 py-1 text-xs font-semibold text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                >
                  2×
                </button>
                <span class="text-xs text-stone-500">sats</span>
              </div>
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
                {if @copper?, do: "Copper ON", else: "Copper OFF"}
              </button>
              <button
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
                {if @keep_bets?, do: "Repeating ✓", else: "Repeat Bets"}
              </button>
            <% end %>
            <%= if @round.phase == :call_the_turn do %>
              <button
                phx-click="skip_ctt"
                class="ml-auto rounded border border-stone-600 bg-stone-700 px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-stone-400 transition-colors hover:border-stone-500 hover:text-stone-200"
              >
                Skip Final Bet
              </button>
            <% end %>
            <button
              phx-click="deal_turn"
              disabled={not @ctt_deal_enabled}
              class={[
                "rounded border px-4 py-1.5 text-xs font-semibold uppercase tracking-wide transition-colors",
                if(@round.phase == :call_the_turn, do: "", else: "ml-auto"),
                if(@ctt_deal_enabled,
                  do: "border-amber-600 bg-amber-700 text-stone-950 hover:bg-amber-600",
                  else: "border-stone-700 bg-stone-800 text-stone-500 cursor-not-allowed opacity-50"
                )
              ]}
            >
              Deal Turn
            </button>
          </div>
        <% end %>

        <%!-- Pending bets --%>
        <%= if @round.phase != :finished and @pending_bets != [] do %>
          <div class="rounded-lg border border-stone-700 bg-stone-800 px-4 py-3">
            <h3 class="mb-2 text-xs font-bold uppercase tracking-widest text-amber-400">Active Bets</h3>
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
        <% end %>

        <%!-- Settlement results --%>
        <%= if @last_settlements != [] do %>
          <.settlement_list settlements={@last_settlements} />
        <% end %>

        <%!-- Round Complete --%>
        <%= if @round.phase == :finished do %>
          <div class="rounded-lg border border-amber-700/50 bg-stone-900 p-4 space-y-3">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-bold uppercase tracking-widest text-amber-400">
                Round Complete
              </h3>
              <button
                phx-click="new_round"
                class="rounded border border-amber-600 bg-amber-600 px-4 py-2 text-xs font-semibold uppercase tracking-widest text-stone-950 transition-colors hover:bg-amber-500"
              >
                New Round
              </button>
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
                  <span class="font-mono font-semibold text-stone-200">{format_sats(@round_wagered)}</span>
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
                    {if @round_net > 0, do: "+#{format_sats(@round_net)}", else: format_sats(@round_net)}
                  </span>
                  sats
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Last turn + recent turns --%>
        <div class="grid gap-4 lg:grid-cols-2">
          <.current_turn_display
            banker_card={if @last_turn, do: @last_turn.loser}
            player_card={if @last_turn, do: @last_turn.winner}
            hock_card={@hock_card}
            turn_number={if @last_turn, do: @last_turn.index}
            split?={@last_turn != nil and @last_turn.split? and @round.phase != :finished}
          />
          <.recent_turns_list turns={@recent_turns} hock_card={@hock_card} />
        </div>

        <%!-- Call the Turn result breakdown --%>
        <%= if @round.phase == :finished and @ctt_bets != [] do %>
          <div class="rounded-lg border border-amber-600/40 bg-stone-900 p-4 space-y-4">
            <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">
              Call the Turn — Result
            </h3>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <div class="mb-2 text-xs text-stone-500">Your Prediction</div>
                <div class="flex gap-3">
                  <%= for {slot_card, idx} <- Enum.with_index(@ctt_slots) do %>
                    <%= if slot_card do %>
                      <.playing_card
                        rank={slot_card.rank}
                        suit={slot_card.suit}
                        label={case idx do
                          0 -> "Banker"
                          1 -> "Player"
                          _ -> "Hock"
                        end}
                      />
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div>
                <div class="mb-2 text-xs text-stone-500">Actual Order</div>
                <div class="flex gap-3">
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
                    Predicted Banker {rank_label(bet.predicted_loser)} → Player {rank_label(bet.predicted_winner)}
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
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp start_round(socket, nonce, balance) do
    server_seed = Fairness.generate_server_seed()
    commitment = Fairness.commit_server_seed(server_seed)
    client_seed = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    shuffle_seed = Fairness.derive_shuffle_seed(server_seed, client_seed, nonce)
    shuffled_deck = Shuffle.shuffle(Deck.new(), shuffle_seed)
    round = Round.new(shuffled_deck)

    db_round_id = persist_round_start(socket, shuffled_deck, commitment, client_seed, nonce)

    assign(socket,
      balance: balance,
      round: round,
      server_seed: server_seed,
      commitment: commitment,
      client_seed: client_seed,
      nonce: nonce,
      shuffled_deck: shuffled_deck,
      db_round_id: db_round_id,
      pending_bets: [],
      last_turn: nil,
      last_settlements: [],
      bet_amount: @default_bet,
      copper?: false,
      keep_bets?: Map.get(socket.assigns, :keep_bets?, false),
      ctt_slots: [nil, nil, nil],
      ctt_selected: nil,
      ctt_amount: @default_bet,
      audit: nil
    )
  end

  defp record_wallet_turn(nil, _turn, _balance, _opts), do: nil

  defp record_wallet_turn(wallet, completed_turn, balance, opts) do
    case Wallet.record_turn(wallet, completed_turn, balance, opts) do
      {:ok, updated} -> updated
      {:error, e} ->
        Logger.warning("Wallet recording failed: #{inspect(e)}")
        wallet
    end
  end

  defp persist_round_start(socket, shuffled_deck, commitment, client_seed, nonce) do
    attrs = %{
      game_session_id: socket.assigns[:session_id],
      nonce: nonce,
      client_seed: client_seed,
      server_seed_hash: commitment,
      algorithm_version: Fairness.algorithm_version(),
      soda_rank: hd(shuffled_deck).rank,
      soda_suit: to_string(hd(shuffled_deck).suit),
      status: :dealing,
      shuffled_deck: Serializer.encode_deck(shuffled_deck)
    }

    case FaroGame.create_round(attrs) do
      {:ok, db_round} -> db_round.id
      {:error, e} -> Logger.warning("Round persistence failed: #{inspect(e)}"); nil
    end
  end

  defp persist_turn(nil, _turn), do: :ok

  defp persist_turn(db_round_id, turn) do
    attrs = %{
      round_id: db_round_id,
      index: turn.index,
      loser_rank: turn.loser.rank,
      loser_suit: to_string(turn.loser.suit),
      winner_rank: turn.winner.rank,
      winner_suit: to_string(turn.winner.suit),
      split: turn.split?,
      bets: Enum.map(turn.bets, &Serializer.encode_bet/1),
      settlements: Enum.map(turn.settlements, &Serializer.encode_settlement/1)
    }

    case FaroGame.create_turn(attrs) do
      {:ok, _} -> :ok
      {:error, e} -> Logger.warning("Turn persistence failed: #{inspect(e)}")
    end
  end

  defp update_round_phase(nil, _phase), do: :ok

  defp update_round_phase(db_round_id, phase) do
    with {:ok, db_round} <- FaroGame.get_round(db_round_id),
         {:ok, _} <- FaroGame.update_round(db_round, %{status: phase}) do
      :ok
    else
      {:error, e} -> Logger.warning("Round phase update failed: #{inspect(e)}")
    end
  end

  defp persist_round_complete(nil, _server_seed, _audit), do: :ok

  defp persist_round_complete(db_round_id, server_seed, audit) do
    with {:ok, db_round} <- FaroGame.get_round(db_round_id),
         {:ok, _} <- FaroGame.update_round(db_round, %{status: :finished, server_seed: server_seed}) do
      :ok
    else
      {:error, e} -> Logger.warning("Round finalization failed: #{inspect(e)}")
    end

    if audit do
      attrs = %{
        round_id: db_round_id,
        algorithm_version: audit.algorithm_version,
        server_commitment: audit.server_commitment,
        server_seed: audit.server_seed,
        client_seed: audit.client_seed,
        nonce: audit.nonce,
        verified: audit.verified?,
        shuffled_deck: Serializer.encode_deck(audit.shuffled_deck),
        soda: Serializer.encode_card(audit.soda),
        turns: Enum.map(audit.turns, &Serializer.encode_audit_turn/1)
      }

      case AuditRecord.create(attrs) do
        {:ok, _} -> :ok
        {:error, e} -> Logger.warning("Audit record persistence failed: #{inspect(e)}")
      end
    end
  end

  defp ctt_available_cards(round, slots) do
    if round.phase == :call_the_turn do
      placed = MapSet.new(Enum.reject(slots, &is_nil/1))
      Enum.reject(round.deck, &MapSet.member?(placed, &1))
    else
      []
    end
  end

  defp ctt_deal_enabled?(:call_the_turn, slots, amount, balance) do
    filled = Enum.count(slots, &(&1 != nil))
    filled == 0 or (filled == 3 and (amount == 0 or amount <= balance))
  end

  defp ctt_deal_enabled?(_, _, _, _), do: true

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
    do: "Rank #{rank_label(rank)} (copper)"

  defp pending_bet_label(%Bet{rank: rank}), do: "Rank #{rank_label(rank)}"
  defp pending_bet_label(%HighCardBet{copper?: true}), do: "High Card (copper)"
  defp pending_bet_label(%HighCardBet{}), do: "High Card"

  defp pending_bet_label(%CallTheTurnBet{predicted_loser: l, predicted_winner: w}),
    do: "Call the Turn: Banker #{rank_label(l)} → Player #{rank_label(w)}"

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
