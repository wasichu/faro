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
          Faro was a fixture of American gambling halls for nearly a century. Its rules are simple: choose a rank, watch two cards come out, and settle the bets. Doublets gave the banker an edge by taking half the stake on the matching rank.
        </p>
        <p class="text-stone-300 leading-relaxed">
          This version keeps the copper bets, casekeeper, and final Call the Turn wager. It also gives you something a saloon table could not: a record of each completed round that you can replay and check for yourself.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Checking the Deal</h2>
        <p class="text-stone-300 leading-relaxed">
          The server publishes a hash of its secret seed before play. When the round ends, it reveals the seed. You can then reproduce the shuffle and compare every dealt card with the audit record.
        </p>
        <p class="text-stone-300 leading-relaxed">
          All bets use FTC, or fake test coins. They have no cash value. You can try the game, follow the odds, and inspect the results without risking money.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">The Payouts</h2>
        <p class="text-stone-300 leading-relaxed">
          Call the Turn pays 4:1 when three different ranks remain, even though the true odds are 5:1. With a pair, the payout is 1:1 against true odds of 2:1. Those payouts give the house an edge of about 16.7% and 33.3%, respectively.
        </p>
        <p class="text-stone-300 leading-relaxed">
          Both are worse odds than standard rank bets. The final wager is optional, and the rules and payouts are there to read before you place it.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">How It Works</h2>
        <p class="text-stone-300 leading-relaxed">
          The rules run in a separate Elixir game engine. Give it the same deck and bets and it produces the same result, without reading a database or changing process state.
        </p>
        <p class="text-stone-300 leading-relaxed">
          That makes it possible to test the settlement rules on their own and replay saved rounds to check the cards and payouts.
        </p>
      </section>
    </div>
    """
  end
end
