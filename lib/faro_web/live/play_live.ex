defmodule FaroWeb.PlayLive do
  use FaroWeb, :live_view

  alias Faro.GameEngine.{Audit, Bet, CallTheTurnBet, Deck, Fairness, HighCardBet, Round, Shuffle}

  @starting_balance 1_000_000
  @default_bet 1_000

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Play") |> start_round(1, @starting_balance)}
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
      existing != nil ->
        {removed, new_bets} = List.pop_at(bets, existing)
        {:noreply, assign(socket, pending_bets: new_bets, balance: balance + removed.amount)}

      amount > balance or round.phase == :finished ->
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
      existing != nil ->
        {removed, new_bets} = List.pop_at(bets, existing)
        {:noreply, assign(socket, pending_bets: new_bets, balance: balance + removed.amount)}

      amount > balance or round.phase == :finished ->
        {:noreply, socket}

      true ->
        bet = %HighCardBet{amount: amount, copper?: copper?}
        {:noreply, assign(socket, pending_bets: bets ++ [bet], balance: balance - amount)}
    end
  end

  def handle_event("remove_bet", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    {bet, new_bets} = List.pop_at(socket.assigns.pending_bets, idx)

    {:noreply,
     assign(socket, pending_bets: new_bets, balance: socket.assigns.balance + bet.amount)}
  end

  def handle_event("set_ctt_loser", %{"rank" => ""}, socket) do
    {:noreply, assign(socket, ctt_loser: nil)}
  end

  def handle_event("set_ctt_loser", %{"rank" => rank_str}, socket) do
    {:noreply, assign(socket, ctt_loser: String.to_integer(rank_str))}
  end

  def handle_event("set_ctt_winner", %{"rank" => ""}, socket) do
    {:noreply, assign(socket, ctt_winner: nil)}
  end

  def handle_event("set_ctt_winner", %{"rank" => rank_str}, socket) do
    {:noreply, assign(socket, ctt_winner: String.to_integer(rank_str))}
  end

  def handle_event("set_ctt_amount", %{"amount" => val}, socket) do
    case Integer.parse(val) do
      {n, ""} when n > 0 -> {:noreply, assign(socket, ctt_amount: n)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("place_ctt_bet", _params, socket) do
    %{
      balance: balance,
      ctt_loser: loser,
      ctt_winner: winner,
      ctt_amount: amount,
      pending_bets: bets
    } = socket.assigns

    if is_nil(loser) or is_nil(winner) or loser == winner or amount > balance do
      {:noreply, socket}
    else
      bet = %CallTheTurnBet{predicted_loser: loser, predicted_winner: winner, amount: amount}
      {:noreply, assign(socket, pending_bets: bets ++ [bet], balance: balance - amount)}
    end
  end

  def handle_event("deal_turn", _params, socket) do
    %{
      round: round,
      pending_bets: bets,
      shuffled_deck: shuffled_deck,
      server_seed: server_seed,
      commitment: commitment,
      client_seed: client_seed,
      nonce: nonce
    } = socket.assigns

    {completed_turn, new_round} = Round.deal_turn(round, bets)

    # Return each bet's stake plus net gain/loss to balance
    delta =
      Enum.reduce(completed_turn.settlements, 0, fn s, acc ->
        acc + s.bet.amount + s.net
      end)

    audit =
      if new_round.phase == :finished do
        Audit.from_round(new_round, commitment, server_seed, client_seed, nonce, shuffled_deck)
        |> Audit.verify_full()
      end

    {:noreply,
     assign(socket,
       round: new_round,
       balance: socket.assigns.balance + delta,
       pending_bets: [],
       last_turn: completed_turn,
       last_settlements: completed_turn.settlements,
       audit: audit
     )}
  end

  def handle_event("keep_bets", _params, socket) do
    %{last_turn: last_turn, pending_bets: existing, balance: balance} = socket.assigns

    restorable = Enum.reject(last_turn.bets, &match?(%CallTheTurnBet{}, &1))

    {new_bets, new_balance} =
      Enum.reduce(restorable, {existing, balance}, fn bet, {bets_acc, bal_acc} ->
        already_placed? =
          case bet do
            %Bet{rank: rank} -> Enum.any?(bets_acc, &match?(%Bet{rank: ^rank}, &1))
            %HighCardBet{} -> Enum.any?(bets_acc, &match?(%HighCardBet{}, &1))
          end

        if already_placed? or bet.amount > bal_acc do
          {bets_acc, bal_acc}
        else
          {bets_acc ++ [bet], bal_acc - bet.amount}
        end
      end)

    {:noreply, assign(socket, pending_bets: new_bets, balance: new_balance)}
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
      |> assign(:turn_number, length(assigns.round.turns))
      |> assign(:remaining, length(assigns.round.deck))
      |> assign(:recent_turns, assigns.round.turns |> Enum.take(-5) |> Enum.reverse())

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
            <span class="text-xs text-stone-400">Turn {@turn_number} / 25</span>
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

        <%!-- Faro board --%>
        <.faro_board
          bets={@board_bets}
          high_card_bet={@high_card_bet_pending}
          on_rank_click={if @round.phase != :finished, do: "place_bet"}
          on_high_card_click={if @round.phase != :finished, do: "place_high_card_bet"}
        />

        <%!-- Betting controls --%>
        <%= if @round.phase != :finished do %>
          <div class="flex flex-wrap items-center gap-3 rounded-lg border border-stone-700 bg-stone-800 px-4 py-3">
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
            <span class="text-xs text-stone-500">← click a rank on the board or High Card bar</span>
          </div>
        <% end %>

        <%!-- Call the Turn area --%>
        <%= if @round.phase == :call_the_turn do %>
          <div class="rounded-lg border border-amber-600 bg-amber-950/30 p-4 space-y-3">
            <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">
              Call the Turn
            </h3>
            <p class="text-xs text-stone-400">
              Three cards remain. Predict the exact order to win 4:1. Two of a kind pays 1:1.
            </p>
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-xs text-stone-500">Remaining:</span>
              <%= for card <- @round.deck do %>
                <span class="rounded border border-stone-600 bg-stone-800 px-2 py-0.5 font-mono text-sm text-stone-200">
                  {rank_label(card.rank)}
                </span>
              <% end %>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <div class="flex items-center gap-2">
                <span class="text-xs text-stone-400">Loser (banker)</span>
                <select
                  phx-change="set_ctt_loser"
                  name="rank"
                  class="rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                >
                  <option value="">—</option>
                  <%= for card <- @round.deck do %>
                    <option value={card.rank} selected={@ctt_loser == card.rank}>
                      {rank_label(card.rank)}
                    </option>
                  <% end %>
                </select>
              </div>
              <span class="text-stone-500">→</span>
              <div class="flex items-center gap-2">
                <span class="text-xs text-stone-400">Winner (player)</span>
                <select
                  phx-change="set_ctt_winner"
                  name="rank"
                  class="rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                >
                  <option value="">—</option>
                  <%= for card <- @round.deck do %>
                    <option value={card.rank} selected={@ctt_winner == card.rank}>
                      {rank_label(card.rank)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="flex items-center gap-2">
                <input
                  type="number"
                  min="1"
                  value={@ctt_amount}
                  phx-change="set_ctt_amount"
                  phx-debounce="300"
                  name="amount"
                  class="w-24 rounded border border-stone-600 bg-stone-900 px-2 py-1 text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
                />
                <span class="text-xs text-stone-500">sats</span>
              </div>
              <button
                phx-click="place_ctt_bet"
                class="rounded border border-amber-600 bg-amber-800 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-stone-100 hover:bg-amber-700 transition-colors"
              >
                Place CTT Bet
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Pending bets + Deal button --%>
        <%= if @round.phase != :finished do %>
          <div class="rounded-lg border border-stone-700 bg-stone-800 p-4">
            <div class="mb-3 flex items-center justify-between gap-2">
              <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">
                Pending Bets
              </h3>
              <div class="flex items-center gap-2">
                <%= if @last_turn && @round.phase != :call_the_turn do %>
                  <button
                    phx-click="keep_bets"
                    class="rounded border border-stone-600 bg-stone-700 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-stone-300 transition-colors hover:border-stone-500 hover:text-stone-100"
                  >
                    Keep Last Bets
                  </button>
                <% end %>
                <button
                  phx-click="deal_turn"
                  class="rounded border border-amber-600 bg-amber-700 px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-stone-950 transition-colors hover:bg-amber-600"
                >
                  Deal Turn
                </button>
              </div>
            </div>
            <%= if @pending_bets == [] do %>
              <p class="text-xs italic text-stone-500">
                No bets — click Deal Turn to advance without betting
              </p>
            <% else %>
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

        <%!-- Last turn + recent turns --%>
        <div class="grid gap-4 lg:grid-cols-2">
          <.current_turn_display
            banker_card={if @last_turn, do: @last_turn.loser}
            player_card={if @last_turn, do: @last_turn.winner}
            turn_number={if @last_turn, do: @last_turn.index}
            split?={if @last_turn, do: @last_turn.split?, else: false}
          />
          <.recent_turns_list turns={@recent_turns} />
        </div>

        <%!-- Settlement results --%>
        <%= if @last_settlements != [] do %>
          <.settlement_list settlements={@last_settlements} />
        <% end %>

        <.casekeeper_display seen={@round.casekeeper.seen} />

        <%!-- Round finished --%>
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
            <p class="text-sm text-stone-300">
              Final balance:
              <span class="font-mono font-semibold text-amber-400">{format_sats(@balance)}</span>
              sats
            </p>
            <%= if @round.deck != [] do %>
              <p class="text-xs text-stone-500">
                Hock: {rank_label(hd(@round.deck).rank)} {suit_symbol(hd(@round.deck).suit)}
              </p>
            <% end %>
          </div>
          <%= if @audit do %>
            <.audit_panel audit={@audit} />
          <% end %>
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

    assign(socket,
      balance: balance,
      round: round,
      server_seed: server_seed,
      commitment: commitment,
      client_seed: client_seed,
      nonce: nonce,
      shuffled_deck: shuffled_deck,
      pending_bets: [],
      last_turn: nil,
      last_settlements: [],
      bet_amount: @default_bet,
      copper?: false,
      ctt_loser: nil,
      ctt_winner: nil,
      ctt_amount: @default_bet,
      audit: nil
    )
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
    do: "CTT: #{rank_label(l)} → #{rank_label(w)}"

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

  defp format_sats(n) when n >= 1_000_000 do
    m = div(n, 1_000_000)
    r = div(rem(n, 1_000_000), 1_000)
    if r == 0, do: "#{m}M", else: "#{m}.#{String.pad_leading("#{r}", 3, "0")}M"
  end

  defp format_sats(n) when n >= 1_000 do
    "#{div(n, 1_000)},#{String.pad_leading("#{rem(n, 1_000)}", 3, "0")}"
  end

  defp format_sats(n), do: Integer.to_string(n)

  defp phase_label(:dealing), do: "Dealing"
  defp phase_label(:call_the_turn), do: "Call the Turn"
  defp phase_label(:finished), do: "Finished"

  defp phase_class(:dealing), do: "border-stone-700 bg-stone-800 text-stone-400"
  defp phase_class(:call_the_turn), do: "border-amber-600 bg-amber-900 text-amber-300"
  defp phase_class(:finished), do: "border-green-700 bg-green-900 text-green-300"
end
