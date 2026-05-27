defmodule FaroWeb.OddsLive do
  use FaroWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Odds")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8 space-y-10">
      <h1 class="font-serif text-3xl font-bold text-amber-400">Odds & Payouts</h1>
      <p class="text-stone-300 leading-relaxed text-lg">
        Faro was historically known as the most player-favourable banking game in America.
        The following describes the odds as implemented in this simulator.
      </p>

      <section class="space-y-4">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Standard Rank Bets</h2>
        <div class="rounded border border-stone-700 bg-stone-800 overflow-hidden">
          <table class="w-full text-sm text-stone-300">
            <thead>
              <tr class="border-b border-stone-700 text-xs uppercase tracking-widest text-stone-500">
                <th class="px-4 py-2 text-left">Event</th>
                <th class="px-4 py-2 text-right">Payout</th>
                <th class="px-4 py-2 text-right">Notes</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-stone-700/50">
              <tr>
                <td class="px-4 py-3">Your rank appears as the player card (winner)</td>
                <td class="px-4 py-3 text-right text-green-400 font-semibold">1:1</td>
                <td class="px-4 py-3 text-right text-stone-500">Win</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Your rank appears as the banker card (loser)</td>
                <td class="px-4 py-3 text-right text-red-400 font-semibold">−1:1</td>
                <td class="px-4 py-3 text-right text-stone-500">Loss</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Neither card matches your rank</td>
                <td class="px-4 py-3 text-right text-stone-400 font-semibold">0</td>
                <td class="px-4 py-3 text-right text-stone-500">Push — stake returned</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Both cards match your rank (doublet)</td>
                <td class="px-4 py-3 text-right text-amber-400 font-semibold">−½</td>
                <td class="px-4 py-3 text-right text-stone-500">Half lost to the house</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-stone-400 text-sm">
          Copper bets reverse the outcome: a copper bet wins on the banker card and loses on
          the player card. Doublet half-loss applies regardless of copper.
        </p>
      </section>

      <section class="space-y-4">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Doublets (Splits)</h2>
        <p class="text-stone-300 leading-relaxed">
          When both cards in a turn share the same rank, any bet on that rank loses
          exactly half its stake to the house. The remaining half is returned. This is the
          house's primary edge in honest faro.
        </p>
        <p class="text-stone-300 leading-relaxed">
          There are 13 ranks, and each rank has 4 copies in the deck. Out of the 52 cards
          dealt as 25 turns plus soda plus hock, doublets occur when a rank's copies happen
          to land in the same turn slot. The copper flag does not affect a doublet.
        </p>
      </section>

      <section class="space-y-4">
        <h2 class="font-serif text-xl font-semibold text-amber-300">High Card Bet</h2>
        <div class="rounded border border-stone-700 bg-stone-800 overflow-hidden">
          <table class="w-full text-sm text-stone-300">
            <thead>
              <tr class="border-b border-stone-700 text-xs uppercase tracking-widest text-stone-500">
                <th class="px-4 py-2 text-left">Event</th>
                <th class="px-4 py-2 text-right">Payout</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-stone-700/50">
              <tr>
                <td class="px-4 py-3">Player card rank &gt; banker card rank</td>
                <td class="px-4 py-3 text-right text-green-400 font-semibold">1:1</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Player card rank &lt; banker card rank</td>
                <td class="px-4 py-3 text-right text-red-400 font-semibold">−1:1</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Same rank (doublet)</td>
                <td class="px-4 py-3 text-right text-stone-400 font-semibold">0</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-stone-400 text-sm">
          Copper reverses: copper high-card wins when player rank is lower, loses when higher.
        </p>
      </section>

      <section class="space-y-4">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Call the Turn</h2>
        <p class="text-stone-300 leading-relaxed">
          When exactly three cards remain in the deck, players may predict the exact dealing
          order of all three cards. The third card is the hock and is never dealt — only the
          banker (first) and player (second) positions are active.
        </p>
        <div class="rounded border border-stone-700 bg-stone-800 overflow-hidden">
          <table class="w-full text-sm text-stone-300">
            <thead>
              <tr class="border-b border-stone-700 text-xs uppercase tracking-widest text-stone-500">
                <th class="px-4 py-2 text-left">Situation</th>
                <th class="px-4 py-2 text-right">True Odds</th>
                <th class="px-4 py-2 text-right">Payout</th>
                <th class="px-4 py-2 text-right">House Edge</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-stone-700/50">
              <tr>
                <td class="px-4 py-3">Three distinct ranks</td>
                <td class="px-4 py-3 text-right text-stone-400">5:1</td>
                <td class="px-4 py-3 text-right text-green-400 font-semibold">4:1</td>
                <td class="px-4 py-3 text-right text-amber-400">16.7%</td>
              </tr>
              <tr>
                <td class="px-4 py-3">Two cards share a rank (cat-hop)</td>
                <td class="px-4 py-3 text-right text-stone-400">2:1</td>
                <td class="px-4 py-3 text-right text-green-400 font-semibold">1:1</td>
                <td class="px-4 py-3 text-right text-amber-400">33.3%</td>
              </tr>
              <tr>
                <td class="px-4 py-3">All three same rank</td>
                <td class="px-4 py-3 text-right text-stone-400">—</td>
                <td class="px-4 py-3 text-right text-stone-500">Void</td>
                <td class="px-4 py-3 text-right text-stone-500">Stake returned</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-stone-400 text-sm">
          The distinct-three-rank case (5 possible orderings, payout on 1) has historically
          high house edge compared to the rest of the game. The cat-hop case (2 orderings,
          payout on 1) is even worse. Most experienced faro players skipped or minimised
          call-the-turn wagers for this reason.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Overall House Edge</h2>
        <p class="text-stone-300 leading-relaxed">
          On standard rank bets, the only house edge comes from doublets. The frequency of
          doublets is low and depends on the specific deck order each round. Historical
          accounts often placed faro's effective house edge at under 2% on rank bets alone —
          unusually competitive for a banking game of the era.
        </p>
        <p class="text-stone-300 leading-relaxed">
          The call-the-turn side bet carries a substantially higher edge and is optional.
          Players who prefer minimal house exposure should stick to rank bets and skip the
          final wager.
        </p>
      </section>
    </div>
    """
  end
end
