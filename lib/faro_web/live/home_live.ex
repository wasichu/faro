defmodule FaroWeb.HomeLive do
  use FaroWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-16 sm:px-6 lg:px-8">
      <div class="text-center">
        <div class="flex items-center justify-center gap-5">
          <img
            src={~p"/images/tiger-king.png"}
            class="h-28 w-auto sm:h-36 drop-shadow-xl"
            alt="Tiger Jack of Spades"
          />
          <h1 class="font-serif text-5xl font-bold tracking-wide text-amber-400 sm:text-6xl">
            Faro
          </h1>
          <img
            src={~p"/images/tiger-queen.png"}
            class="h-28 w-auto sm:h-36 drop-shadow-xl"
            alt="Tiger Queen of Hearts"
          />
        </div>
        <p class="mt-3 font-serif text-lg text-stone-400 italic">
          The Gentleman's Game of the American Frontier
        </p>
        <p class="mx-auto mt-6 max-w-2xl text-stone-300 leading-relaxed">
          Faro was the most popular card game in America from the 1820s through the early 1900s.
          When honestly dealt, faro offered players unusually favorable odds for a banking game,
          helping make it the dominant gambling game of the American frontier.
        </p>
        <div class="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
          <.link
            navigate={~p"/play"}
            class="rounded border border-amber-600 bg-amber-600 px-8 py-3 text-sm font-semibold uppercase tracking-widest text-stone-950 hover:bg-amber-500 transition-colors"
          >
            Play Now
          </.link>
          <.link
            navigate={~p"/rules"}
            class="rounded border border-stone-600 px-8 py-3 text-sm font-semibold uppercase tracking-widest text-stone-300 hover:border-amber-600 hover:text-amber-400 transition-colors"
          >
            Learn the Rules
          </.link>
        </div>
      </div>

      <div class="mt-20 grid gap-8 sm:grid-cols-3">
        <div class="rounded-lg border border-stone-700 bg-stone-800 p-6 text-center">
          <div class="mb-3 text-3xl">🎴</div>
          <h3 class="font-serif text-lg font-semibold text-amber-400">Historically Accurate</h3>
          <p class="mt-2 text-sm text-stone-400 leading-relaxed">
            Authentic Faro rules including copper bets, doublets, call-the-turn, and the
            high card bar — exactly as dealt in frontier saloons.
          </p>
        </div>
        <div class="rounded-lg border border-stone-700 bg-stone-800 p-6 text-center">
          <div class="mb-3 text-3xl">🔐</div>
          <h3 class="font-serif text-lg font-semibold text-amber-400">Provably Fair</h3>
          <p class="mt-2 text-sm text-stone-400 leading-relaxed">
            Every shuffle is verifiable. Server seed commitment published before play,
            revealed after. HMAC-SHA256 counter-mode PRNG. Nothing hidden.
          </p>
        </div>
        <div class="rounded-lg border border-stone-700 bg-stone-800 p-6 text-center">
          <div class="mb-3 text-3xl">🔎</div>
          <h3 class="font-serif text-lg font-semibold text-amber-400">Built for Replay</h3>
          <p class="mt-2 text-sm text-stone-400 leading-relaxed">
            Every completed round can be inspected, replayed, and independently
            verified card by card.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
