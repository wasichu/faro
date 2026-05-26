defmodule FaroWeb.GameComponents do
  @moduledoc """
  UI components specific to the Faro game table.

  All components are pure display — no LiveView events wired here.
  Mock data is passed via assigns from the parent LiveView.
  """
  use Phoenix.Component

  @ranks 1..13
  @board_top_row [13, 12, 11, 10, 9, 8, 7]
  @board_bottom_row [1, 2, 3, 4, 5, 6]

  # ---------------------------------------------------------------------------
  # Faro Board
  # ---------------------------------------------------------------------------

  attr :bets, :map, default: %{}
  attr :high_card_bet, :map, default: nil

  def faro_board(assigns) do
    assigns =
      assigns
      |> assign(:top_row, @board_top_row)
      |> assign(:bottom_row, @board_bottom_row)

    ~H"""
    <div class="rounded-lg border-2 border-amber-700 bg-green-950 p-4 shadow-2xl">
      <.high_card_bar bet={@high_card_bet} />
      <div class="mt-3 grid grid-cols-7 gap-2">
        <%= for rank <- @top_row do %>
          <.board_slot rank={rank} bet={Map.get(@bets, rank)} />
        <% end %>
      </div>
      <div class="mt-2 grid grid-cols-7 gap-2">
        <%= for rank <- @bottom_row do %>
          <.board_slot rank={rank} bet={Map.get(@bets, rank)} />
        <% end %>
        <div />
      </div>
    </div>
    """
  end

  attr :bet, :map, default: nil

  defp high_card_bar(assigns) do
    ~H"""
    <div class="flex items-center justify-between rounded border border-amber-600/50 bg-green-900 px-4 py-2">
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

  defp board_slot(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-1 cursor-pointer group">
      <div class="relative flex h-14 w-10 flex-col items-center justify-between rounded border border-stone-400/30 bg-amber-50 px-1 py-0.5 shadow-md transition-transform group-hover:-translate-y-0.5 group-hover:shadow-lg">
        <span class="self-start text-[10px] font-bold leading-none text-stone-800">
          {rank_label(@rank)}
        </span>
        <span class="text-sm text-stone-800">♠</span>
        <span class="self-end rotate-180 text-[10px] font-bold leading-none text-stone-800">
          {rank_label(@rank)}
        </span>
      </div>
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
      <div class="relative flex h-24 w-16 flex-col items-start justify-between rounded-lg border border-stone-300 bg-amber-50 p-1.5 shadow-lg">
        <div class={["text-sm font-bold leading-none", suit_color(@suit)]}>
          <div>{rank_label(@rank)}</div>
          <div>{suit_symbol(@suit)}</div>
        </div>
        <div class={["self-center text-2xl leading-none", suit_color(@suit)]}>
          {suit_symbol(@suit)}
        </div>
        <div class={["rotate-180 self-end text-sm font-bold leading-none", suit_color(@suit)]}>
          <div>{rank_label(@rank)}</div>
          <div>{suit_symbol(@suit)}</div>
        </div>
      </div>
    </div>
    """
  end

  def card_back(assigns) do
    ~H"""
    <div class="flex h-24 w-16 items-center justify-center rounded-lg border border-stone-600 bg-green-900 shadow-lg">
      <span class="text-2xl text-amber-600/60">✦</span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Current Turn Display
  # ---------------------------------------------------------------------------

  attr :banker_card, :map, default: nil
  attr :player_card, :map, default: nil
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
              <span class="text-stone-500">{if turn.split?, do: "≡", else: "→"}</span>
              <span class={["font-mono", suit_color(turn.winner.suit)]}>
                {rank_label(turn.winner.rank)}{suit_symbol(turn.winner.suit)}
              </span>
              <%= if turn.split? do %>
                <span class="text-[10px] text-orange-400 uppercase">split</span>
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

  defp suit_color(:hearts), do: "text-red-600"
  defp suit_color(:diamonds), do: "text-red-600"
  defp suit_color(:spades), do: "text-stone-900"
  defp suit_color(:clubs), do: "text-stone-900"

  defp format_sats(n) when n >= 1_000_000 do
    m = div(n, 1_000_000)
    rem = div(rem(n, 1_000_000), 1_000)
    if rem == 0, do: "#{m}M", else: "#{m}.#{String.pad_leading("#{rem}", 3, "0")}M"
  end

  defp format_sats(n) when n >= 1_000 do
    "#{div(n, 1_000)},#{String.pad_leading("#{rem(n, 1_000)}", 3, "0")}"
  end

  defp format_sats(n), do: Integer.to_string(n)
end
