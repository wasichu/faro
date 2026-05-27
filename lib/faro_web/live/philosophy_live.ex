defmodule FaroWeb.PhilosophyLive do
  use FaroWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Philosophy")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8 space-y-10">
      <h1 class="font-serif text-3xl font-bold text-amber-400">Philosophy</h1>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Why Faro?</h2>
        <p class="text-stone-300 leading-relaxed">
          Faro dominated American gambling halls for nearly a century in part because, when honestly dealt, it offered players unusually favorable odds for a banking game.
          On standard bets, the banker’s primary mathematical advantage came from doublets: when both revealed cards shared a rank and bets on that rank lost half their stake.
          Compared to most gambling games of its era, Faro’s house edge was remarkably small, helping make it the game of frontier saloons, miners, and professional gamblers alike.
        </p>
        <p class="text-stone-300 leading-relaxed">
          We build Faro because it deserves a serious digital treatment. Not a novelty, not a
          retro skin over a blackjack engine — but an accurate simulation of a real game with
          a real history.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Fiat-Free from Day One</h2>
        <p class="text-stone-300 leading-relaxed">
          We denominate in satoshis. There is no points system, no in-game currency, no
          conversion layer. A satoshi is a satoshi. This means wagering is real from the first
          hand — even when played on regtest or signet, the accounting is honest.
        </p>
        <p class="text-stone-300 leading-relaxed">
          The v1 implementation uses play coins (FTC — Feathercoin testnet) to let players
          experience the full betting flow without risking real value. Lightning wagering
          follows when the game is proven stable.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Honesty Over House Edge</h2>
        <p class="text-stone-300 leading-relaxed">
          The call-the-turn payout of 4:1 on a true 5:1 bet, and 1:1 on a true 2:1 cat-hop,
          are the historical house payouts. We implement them exactly. The house edge on
          call-the-turn is 16.67% and 33.33% respectively — higher than standard bets,
          and we say so plainly.
        </p>
        <p class="text-stone-300 leading-relaxed">
          Every audit transcript is publicly verifiable. The shuffle seed commitment is
          published before play. We cannot change the cards after you bet.
          That is the entire point.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Pure Game Engine</h2>
        <p class="text-stone-300 leading-relaxed">
          The game logic lives in a pure Elixir module with no database calls, no process
          state, and no side effects. Every function is a pure transformation of data.
          This makes the engine independently testable, auditable, and provably correct
          by property-based testing against the mathematical rules.
        </p>
      </section>
    </div>
    """
  end
end
