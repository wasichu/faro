defmodule FaroWeb.FairnessLive do
  use FaroWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Fairness")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8 space-y-10">
      <h1 class="font-serif text-3xl font-bold text-amber-400">Provably Fair</h1>
      <p class="text-stone-300 leading-relaxed text-lg">
        Every shuffle is mathematically verifiable. No trust required.
      </p>

      <section class="space-y-4">
        <h2 class="font-serif text-xl font-semibold text-amber-300">The Protocol</h2>
        <ol class="space-y-4 text-stone-300">
          <li class="flex gap-4">
            <span class="flex-shrink-0 flex h-7 w-7 items-center justify-center rounded-full border border-amber-600 text-xs font-bold text-amber-400">
              1
            </span>
            <div>
              <strong class="text-stone-100">Before the round</strong> — the server generates a
              random 32-byte seed and publishes its SHA-256 hash (the commitment). You can
              verify this hash before any cards are dealt.
            </div>
          </li>
          <li class="flex gap-4">
            <span class="flex-shrink-0 flex h-7 w-7 items-center justify-center rounded-full border border-amber-600 text-xs font-bold text-amber-400">
              2
            </span>
            <div>
              <strong class="text-stone-100">You provide a client seed</strong> — any string of
              your choice, submitted before the round begins. This ensures the server cannot
              predict your input when it generated its seed.
            </div>
          </li>
          <li class="flex gap-4">
            <span class="flex-shrink-0 flex h-7 w-7 items-center justify-center rounded-full border border-amber-600 text-xs font-bold text-amber-400">
              3
            </span>
            <div>
              <strong class="text-stone-100">The shuffle seed is derived</strong>
              — using
              HMAC-SHA256 with the server seed as key and
              <code class="rounded bg-stone-800 px-1 text-amber-300">client_seed || nonce</code>
              as data.
              Neither party alone controls the outcome.
            </div>
          </li>
          <li class="flex gap-4">
            <span class="flex-shrink-0 flex h-7 w-7 items-center justify-center rounded-full border border-amber-600 text-xs font-bold text-amber-400">
              4
            </span>
            <div>
              <strong class="text-stone-100">After the round</strong> — the server reveals the
              original seed. You verify SHA-256(seed) matches the commitment, re-derive the
              shuffle, and confirm every card dealt matches the audit transcript.
            </div>
          </li>
        </ol>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">The Shuffle Algorithm</h2>
        <p class="text-stone-300 leading-relaxed">
          The shuffle uses Fisher-Yates (Knuth) with a counter-mode HMAC-SHA256 PRNG.
          Each random index is generated as:
        </p>
        <div class="rounded border border-stone-700 bg-stone-900 p-4 font-mono text-sm text-amber-300">
          random_bytes(i) = HMAC-SHA256(key: shuffle_seed, data: &lt;&lt;i::big-64&gt;&gt;)
        </div>
        <p class="text-stone-300 leading-relaxed">
          The 32-byte result is decoded as a big-endian unsigned integer and reduced modulo the
          current range. The modulo bias is negligible — range ≤ 52, entropy = 2²⁵⁶.
        </p>
      </section>

      <section class="space-y-3">
        <h2 class="font-serif text-xl font-semibold text-amber-300">Algorithm Version</h2>
        <div class="rounded border border-stone-700 bg-stone-800 p-4">
          <span class="font-mono text-sm text-amber-300">faro-shuffle-v1</span>
          <p class="mt-2 text-sm text-stone-400">
            The algorithm version is embedded in every audit transcript. Future algorithm
            changes will use a new version identifier, preserving the ability to verify
            historical rounds.
          </p>
        </div>
      </section>
    </div>
    """
  end
end
