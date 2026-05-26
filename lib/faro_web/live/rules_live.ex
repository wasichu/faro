defmodule FaroWeb.RulesLive do
  use FaroWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Rules")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8 space-y-10">
      <h1 class="font-serif text-3xl font-bold text-amber-400">Rules of Faro</h1>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">The Deck & Setup</h2>
        <p class="text-stone-300 leading-relaxed">
          Faro is played with a standard 52-card deck. Before each round the dealer burns
          the first card — the <strong class="text-amber-400">soda</strong> — face up. It counts
          in the casekeeper but no bets are settled on it. The last card remaining after all
          turns is the <strong class="text-amber-400">hock</strong>; it is revealed but never
          dealt.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Betting</h2>
        <p class="text-stone-300 leading-relaxed">
          Players place bets on any of the 13 rank positions on the layout before each turn.
          A bet on a rank wins if that rank appears as the
          <strong class="text-amber-400">player card</strong>
          (second card dealt) and loses if it appears as the
          <strong class="text-amber-400">banker card</strong>
          (first card dealt). All other bets push.
        </p>
        <p class="text-stone-300 leading-relaxed">
          Placing a <strong class="text-amber-400">copper</strong> (penny) on a bet reverses it:
          the bet then wins on the banker card and loses on the player card. Copper bets pay
          the same 1:1 as regular bets.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Doublets (Splits)</h2>
        <p class="text-stone-300 leading-relaxed">
          When both cards in a turn share the same rank, it is a
          <strong class="text-amber-400">doublet</strong>
          or split. Any bet on that rank loses half its stake to the house — the remainder is
          returned. The copper flag does not affect a split; it always costs half.
          Bets on other ranks push.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">High Card</h2>
        <p class="text-stone-300 leading-relaxed">
          The high card bar at the top of the layout accepts a bet on relative card value.
          The bet wins if the player card has a higher rank than the banker card, and loses
          if it is lower. A doublet (same rank) is a push. Copper is supported.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Call the Turn</h2>
        <p class="text-stone-300 leading-relaxed">
          When exactly three cards remain in the deck, the round enters the
          <strong class="text-amber-400">call-the-turn</strong>
          phase. Players predict the
          exact order: which rank is dealt as the banker card and which as the player card.
          The third card is the hock.
        </p>
        <div class="rounded border border-stone-700 bg-stone-800 p-4 space-y-2 text-sm text-stone-300">
          <div class="flex justify-between">
            <span>Three distinct ranks remaining</span>
            <span class="text-amber-400">4:1 payout</span>
          </div>
          <div class="flex justify-between">
            <span>Two cards same rank (cat-hop)</span>
            <span class="text-amber-400">1:1 payout</span>
          </div>
          <div class="flex justify-between">
            <span>All three same rank</span>
            <span class="text-stone-500">Void — stake returned</span>
          </div>
        </div>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">The Casekeeper</h2>
        <p class="text-stone-300 leading-relaxed">
          The casekeeper tracks how many cards of each rank have been seen (including the soda).
          Each rank starts with 4 copies. As cards are dealt the count decreases, letting players
          identify favourable odds and last-turn opportunities.
        </p>
      </section>
    </div>
    """
  end
end
