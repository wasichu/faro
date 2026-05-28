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
          Faro is played with a standard 52-card deck. Before the round begins, the deck is
          shuffled and one card is removed from play as the <strong class="text-amber-400">soda</strong>
          card. The soda card is revealed immediately and is not involved in bets.
        </p>
        <p class="text-stone-300 leading-relaxed">
          The remaining 51 cards produce 25 betting turns. On most turns, players place bets before the
          dealer reveals two cards: the <strong class="text-amber-400">banker card</strong> and the 
          <strong class="text-amber-400">player card</strong>.
          The final turn is different and uses the last three remaining cards.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Gameplay</h2>
        <p class="text-stone-300 leading-relaxed">
          On each turn, players place bets on card ranks before two cards are revealed. The
          first revealed card is the <strong class="text-amber-400">banker card</strong>, which
          loses for standard bets. The second is the <strong class="text-amber-400">player card</strong>,
          which wins for standard bets. Standard bets pay 1:1.
        </p>
        <p class="text-stone-300 leading-relaxed">
          The other bet type is a <strong class="text-amber-400">copper</strong> bet,
          which reverses the meaning of the standard bet, i.e., the
          <strong class="text-amber-400">banker card</strong> wins and the
          <strong class="text-amber-400">player card</strong> loses.
          Copper bets pay the same 1:1 as regular bets.
        </p>
        <p class="text-stone-300 leading-relaxed">
          When only three cards remain, the game enters its final phase,
          <strong class="text-amber-400">Call the Turn</strong>. Players may attempt to predict
          the exact order of the final three cards or skip the final bet entirely.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">High Card Bets</h2>
        <p class="text-stone-300 leading-relaxed">
          The high card bar at the top of the layout accepts a bet on relative card value.
          The bet wins if the player card has a higher rank than the banker card, and loses
          if it is lower. Copper is supported; copper high
          card bets win if the player card has a lower rank than the banker card. 
          A doublet (same rank) is a push. 
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
        <h2 class="font-serif text-xl font-semibold text-amber-300">Call the Turn</h2>
        <p class="text-stone-300 leading-relaxed">
          When exactly three cards remain in the deck, the round enters the
          <strong class="text-amber-400">call-the-turn</strong>
          phase. Players predict the
          exact order of the remaining three cards: 
          which card is dealt as the banker card and which as the player card.
          The third card (the last one in the deck) is known the <strong class="text-amber-400">hock</strong>.
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
          Each rank has 4 copies. As cards are dealt the count of remaining decreases, letting
          players identify favourable odds and last-turn opportunities.
        </p>
      </section>
    </div>
    """
  end
end
