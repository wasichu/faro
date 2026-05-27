defmodule FaroWeb.GameComponents do
  @moduledoc """
  UI components specific to the Faro game table.

  All components are pure display — no LiveView events wired here.
  Mock data is passed via assigns from the parent LiveView.
  """
  use Phoenix.Component

  @ranks 1..13
  @board_top_row [13, 12, 11, 10, 9, 8]
  @board_bottom_row [1, 2, 3, 4, 5, 6]

  # ---------------------------------------------------------------------------
  # Faro Board
  # ---------------------------------------------------------------------------

  attr :bets, :map, default: %{}
  attr :high_card_bet, :map, default: nil
  attr :on_rank_click, :string, default: nil
  attr :on_high_card_click, :string, default: nil

  def faro_board(assigns) do
    assigns =
      assigns
      |> assign(:top_row, @board_top_row)
      |> assign(:bottom_row, @board_bottom_row)

    ~H"""
    <div class="rounded-lg border-2 border-amber-700 bg-green-950 p-4 shadow-2xl">
      <div class="mx-auto w-2/3">
        <.high_card_bar bet={@high_card_bet} on_click={@on_high_card_click} />
      </div>
      <%!-- Single 7-col grid: top row (row 1), 7 alone in col 7 (row 2), bottom row (row 3) --%>
      <div class="mt-3 grid grid-cols-7 gap-2">
        <%= for rank <- @top_row do %>
          <.board_slot rank={rank} bet={Map.get(@bets, rank)} on_click={@on_rank_click} />
        <% end %>
        <div class="col-start-7 row-start-2">
          <.board_slot rank={7} bet={Map.get(@bets, 7)} on_click={@on_rank_click} />
        </div>
        <%= for rank <- @bottom_row do %>
          <div class="row-start-3">
            <.board_slot rank={rank} bet={Map.get(@bets, rank)} on_click={@on_rank_click} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :bet, :map, default: nil
  attr :on_click, :string, default: nil

  defp high_card_bar(assigns) do
    ~H"""
    <div
      class={[
        "flex items-center justify-between rounded border border-amber-600/50 bg-green-900 px-4 py-2",
        if(@on_click, do: "cursor-pointer hover:bg-green-800 transition-colors", else: "")
      ]}
      phx-click={@on_click}
    >
      <span class="font-serif text-xs font-bold tracking-widest text-amber-400 uppercase">
        High Card
      </span>
      <div class="flex items-center gap-2">
        <span class="text-xs text-stone-400">Player card beats dealer card</span>
        <%= if @bet do %>
          <.bet_marker bet={@bet} />
        <% else %>
          <div class="h-5 w-5 rounded-full border border-stone-600 opacity-40" />
        <% end %>
      </div>
    </div>
    """
  end

  attr :rank, :integer, required: true
  attr :bet, :map, default: nil
  attr :on_click, :string, default: nil

  defp board_slot(assigns) do
    ~H"""
    <div
      class="flex flex-col items-center gap-1 cursor-pointer group"
      phx-click={@on_click}
      phx-value-rank={@rank}
    >
      <img
        src={card_path(@rank, :spades)}
        alt={rank_label(@rank)}
        class="h-32 w-24 drop-shadow-md transition-transform group-hover:-translate-y-0.5 group-hover:drop-shadow-lg"
      />
      <div class="h-4 flex items-center justify-center">
        <%= if @bet do %>
          <.bet_marker bet={@bet} />
        <% else %>
          <div class="h-3 w-3 rounded-full border border-stone-600/40 opacity-30" />
        <% end %>
      </div>
    </div>
    """
  end

  attr :bet, :map, required: true

  defp bet_marker(assigns) do
    ~H"""
    <div class={[
      "h-4 w-4 rounded-full flex items-center justify-center shadow-sm",
      if(@bet.copper?,
        do: "bg-orange-700 ring-1 ring-orange-500",
        else: "bg-amber-500 ring-1 ring-amber-300"
      )
    ]}>
      <%= if @bet.copper? do %>
        <span class="text-[7px] font-bold text-orange-200">C</span>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Playing Card (displayed face-up in the current turn area)
  # ---------------------------------------------------------------------------

  attr :rank, :integer, required: true
  attr :suit, :atom, required: true
  attr :label, :string, default: nil

  def playing_card(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-1">
      <%= if @label do %>
        <span class="text-xs uppercase tracking-widest text-stone-400">{@label}</span>
      <% end %>
      <img
        src={card_path(@rank, @suit)}
        alt={card_alt(@rank, @suit)}
        class="h-32 w-24 drop-shadow-lg"
      />
    </div>
    """
  end

  def card_back(assigns) do
    ~H"""
    <img src={card_back_path()} alt="card back" class="h-32 w-24 drop-shadow-md" />
    """
  end

  # ---------------------------------------------------------------------------
  # Current Turn Display
  # ---------------------------------------------------------------------------

  attr :banker_card, :map, default: nil
  attr :player_card, :map, default: nil
  attr :hock_card, :map, default: nil
  attr :turn_number, :integer, default: nil
  attr :split?, :boolean, default: false

  def current_turn_display(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-4">
      <h3 class="mb-3 text-xs font-bold uppercase tracking-widest text-amber-400">
        {if @turn_number, do: "Turn #{@turn_number}", else: "Awaiting Deal"}
      </h3>
      <div class="flex items-end gap-6">
        <div class="flex flex-col items-center gap-1">
          <%= if @banker_card do %>
            <.playing_card rank={@banker_card.rank} suit={@banker_card.suit} label="Banker" />
          <% else %>
            <span class="mb-1 text-xs uppercase tracking-widest text-stone-400">Banker</span>
            <.card_back />
          <% end %>
        </div>
        <div class="mb-8 text-xl text-stone-500">
          {if @split?, do: "≡", else: "→"}
        </div>
        <div class="flex flex-col items-center gap-1">
          <%= if @player_card do %>
            <.playing_card rank={@player_card.rank} suit={@player_card.suit} label="Player" />
          <% else %>
            <span class="mb-1 text-xs uppercase tracking-widest text-stone-400">Player</span>
            <.card_back />
          <% end %>
        </div>
        <%= if @hock_card do %>
          <div class="mb-8 text-xl text-stone-500">→</div>
          <.playing_card rank={@hock_card.rank} suit={@hock_card.suit} label="Hock" />
        <% end %>
      </div>
      <%= if @split? do %>
        <p class="mt-2 text-xs text-orange-400">Split — banker takes half</p>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Recent Turns
  # ---------------------------------------------------------------------------

  attr :turns, :list, default: []
  attr :hock_card, :map, default: nil

  def recent_turns_list(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-4">
      <h3 class="mb-3 text-xs font-bold uppercase tracking-widest text-amber-400">Recent Turns</h3>
      <%= if @turns == [] do %>
        <p class="text-xs text-stone-500 italic">No turns played yet</p>
      <% else %>
        <ol class="space-y-1.5">
          <%= for turn <- @turns do %>
            <li class="flex items-center gap-2 text-sm">
              <span class="w-6 text-right text-xs text-stone-500">T{turn.index}</span>
              <span class={["font-mono", suit_color(turn.loser.suit)]}>
                {rank_label(turn.loser.rank)}{suit_symbol(turn.loser.suit)}
              </span>
              <% ctt_turn? = turn.index == 25 and @hock_card != nil %>
              <span class="text-stone-500">{if turn.split? and not ctt_turn?, do: "≡", else: "→"}</span>
              <span class={["font-mono", suit_color(turn.winner.suit)]}>
                {rank_label(turn.winner.rank)}{suit_symbol(turn.winner.suit)}
              </span>
              <%= if ctt_turn? do %>
                <span class="text-stone-500">→</span>
                <span class={["font-mono", suit_color(@hock_card.suit)]}>
                  {rank_label(@hock_card.rank)}{suit_symbol(@hock_card.suit)}
                </span>
                <span class="text-[10px] text-stone-500 uppercase">hock</span>
              <% end %>
            </li>
          <% end %>
        </ol>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Casekeeper
  # ---------------------------------------------------------------------------

  attr :seen, :map, required: true

  def casekeeper_display(assigns) do
    assigns = assign(assigns, :all_ranks, Enum.to_list(@ranks))

    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-4">
      <h3 class="mb-3 text-xs font-bold uppercase tracking-widest text-amber-400">Casekeeper</h3>
      <div class="grid grid-cols-7 gap-x-3 gap-y-2 sm:grid-cols-13">
        <%= for rank <- @all_ranks do %>
          <.casekeeper_rank rank={rank} seen={Map.get(@seen, rank, 0)} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :rank, :integer, required: true
  attr :seen, :integer, required: true

  defp casekeeper_rank(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-0.5">
      <span class={[
        "text-xs font-bold",
        if(@seen == 4, do: "text-stone-600", else: "text-stone-300")
      ]}>
        {rank_label(@rank)}
      </span>
      <div class="flex gap-0.5">
        <%= for i <- 1..4 do %>
          <div class={[
            "h-2 w-2 rounded-full",
            if(i <= @seen, do: "bg-amber-500", else: "bg-stone-700")
          ]} />
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Call the Turn Area
  # ---------------------------------------------------------------------------

  attr :phase, :atom, default: :dealing

  def call_the_turn_area(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border p-4 transition-opacity",
      if(@phase == :call_the_turn,
        do: "border-amber-600 bg-amber-950/40",
        else: "border-stone-700 bg-stone-800 opacity-50"
      )
    ]}>
      <h3 class="mb-1 text-xs font-bold uppercase tracking-widest text-amber-400">
        Call the Turn
      </h3>
      <p class="mb-3 text-xs text-stone-400">
        <%= if @phase == :call_the_turn do %>
          Three cards remain. Predict the exact order to win 4:1. Two of a kind pays 1:1.
        <% else %>
          Available when three cards remain in the deck.
        <% end %>
      </p>
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs text-stone-400">Banker</span>
          <div class="h-8 w-14 rounded border border-stone-600 bg-stone-700 text-center text-xs leading-8 text-stone-400">
            rank
          </div>
        </div>
        <span class="text-stone-500">→</span>
        <div class="flex items-center gap-2">
          <span class="text-xs text-stone-400">Player</span>
          <div class="h-8 w-14 rounded border border-stone-600 bg-stone-700 text-center text-xs leading-8 text-stone-400">
            rank
          </div>
        </div>
        <div class="h-8 w-20 rounded border border-stone-600 bg-stone-700 text-center text-xs leading-8 text-stone-400">
          amount
        </div>
        <div class={[
          "rounded px-3 py-1.5 text-xs font-semibold uppercase tracking-wide",
          if(@phase == :call_the_turn,
            do: "bg-amber-600 text-stone-950 cursor-pointer hover:bg-amber-500",
            else: "bg-stone-700 text-stone-500 cursor-not-allowed"
          )
        ]}>
          Place Bet
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Balance Display
  # ---------------------------------------------------------------------------

  attr :balance_sats, :integer, required: true

  def balance_display(assigns) do
    ~H"""
    <div class="flex items-center gap-2 rounded border border-stone-700 bg-stone-800 px-3 py-2">
      <span class="text-xs uppercase tracking-widest text-stone-400">Balance</span>
      <span class="font-mono text-sm font-semibold text-amber-400">
        {format_sats(@balance_sats)}
      </span>
      <span class="text-xs text-stone-500">sats</span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Settlement List
  # ---------------------------------------------------------------------------

  attr :settlements, :list, default: []

  def settlement_list(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-4">
      <h3 class="mb-3 text-xs font-bold uppercase tracking-widest text-amber-400">
        Turn Settlements
      </h3>
      <%= if @settlements == [] do %>
        <p class="text-xs italic text-stone-500">No bets were placed</p>
      <% else %>
        <ul class="space-y-1.5">
          <%= for s <- @settlements do %>
            <li class="flex items-center justify-between text-sm">
              <span class="text-stone-300">{settlement_label(s.bet)}</span>
              <span class={["font-mono font-semibold", outcome_color(s.outcome)]}>
                {outcome_label(s.outcome, s.net)}
              </span>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Audit Panel
  # ---------------------------------------------------------------------------

  attr :audit, :map, required: true

  def audit_panel(assigns) do
    ~H"""
    <div class="rounded-lg border border-amber-700/50 bg-stone-900 p-4 space-y-3">
      <div class="flex items-center justify-between">
        <h3 class="text-xs font-bold uppercase tracking-widest text-amber-400">Audit Transcript</h3>
        <span class={[
          "rounded px-2 py-0.5 text-xs font-semibold",
          if(@audit.verified?,
            do: "bg-green-900 text-green-400",
            else: "bg-red-900 text-red-400"
          )
        ]}>
          {if @audit.verified?, do: "✓ Verified", else: "✗ Failed"}
        </span>
      </div>
      <div class="space-y-2 text-xs font-mono">
        <div class="flex flex-col gap-0.5">
          <span class="text-stone-500 font-sans">Algorithm</span>
          <span class="text-amber-300 break-all">{@audit.algorithm_version}</span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-stone-500 font-sans">Commitment (pre-game)</span>
          <span class="text-stone-300 break-all">{@audit.server_commitment}</span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-stone-500 font-sans">Server Seed (revealed)</span>
          <span class="text-stone-300 break-all">
            {Base.encode16(@audit.server_seed, case: :lower)}
          </span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-stone-500 font-sans">Client Seed</span>
          <span class="text-stone-300 break-all">{@audit.client_seed}</span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-stone-500 font-sans">Nonce</span>
          <span class="text-stone-300">{@audit.nonce}</span>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp rank_label(1), do: "A"
  defp rank_label(11), do: "J"
  defp rank_label(12), do: "Q"
  defp rank_label(13), do: "K"
  defp rank_label(n), do: Integer.to_string(n)

  defp suit_symbol(:spades), do: "♠"
  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"

  defp suit_color(:hearts), do: "text-rose-400"
  defp suit_color(:diamonds), do: "text-rose-400"
  defp suit_color(:spades), do: "text-stone-200"
  defp suit_color(:clubs), do: "text-stone-200"

  # ---- Card asset paths ----

  def card_path(rank, suit), do: "/images/cards/#{card_rank_name(rank)}_#{suit}.svg"
  def card_back_path, do: "/images/cards/back.svg"

  defp card_rank_name(1), do: "ace"
  defp card_rank_name(11), do: "jack"
  defp card_rank_name(12), do: "queen"
  defp card_rank_name(13), do: "king"
  defp card_rank_name(n), do: Integer.to_string(n)

  defp card_alt(rank, suit),
    do: "#{rank_label(rank)} of #{suit |> to_string() |> String.capitalize()}"

  def format_sats(n) when n < 0, do: "-" <> format_sats(-n)

  def format_sats(n) when n >= 1_000_000 do
    m = div(n, 1_000_000)
    rem = div(rem(n, 1_000_000), 1_000)
    if rem == 0, do: "#{m}M", else: "#{m}.#{String.pad_leading("#{rem}", 3, "0")}M"
  end

  def format_sats(n) when n >= 1_000 do
    "#{div(n, 1_000)},#{String.pad_leading("#{rem(n, 1_000)}", 3, "0")}"
  end

  def format_sats(n), do: Integer.to_string(n)

  defp settlement_label(%{rank: rank, copper?: copper?}) do
    flag = if copper?, do: " (copper)", else: ""
    "Rank #{rank_label(rank)}#{flag}"
  end

  defp settlement_label(%{predicted_loser: l, predicted_winner: w}) do
    "Call the Turn: Banker #{rank_label(l)} → Player #{rank_label(w)}"
  end

  defp settlement_label(%{copper?: copper?}) do
    flag = if copper?, do: " (copper)", else: ""
    "High Card#{flag}"
  end

  defp outcome_color(:win), do: "text-green-400"
  defp outcome_color(:loss), do: "text-red-400"
  defp outcome_color(:push), do: "text-stone-400"
  defp outcome_color(:split), do: "text-orange-400"
  defp outcome_color(:void), do: "text-stone-500"

  defp outcome_label(:win, net), do: "+#{format_sats(net)}"
  defp outcome_label(:loss, net), do: "#{format_sats(net)}"
  defp outcome_label(:push, _net), do: "push"
  defp outcome_label(:split, net), do: "#{format_sats(net)}"
  defp outcome_label(:void, _net), do: "void"
end
