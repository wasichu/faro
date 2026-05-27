defmodule FaroWeb.AuditShuffleLive do
  use FaroWeb, :live_view

  alias Faro.GameEngine.{Deck, Fairness, Shuffle}
  alias FaroWeb.GameComponents

  def mount(params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Manual Shuffle Verifier",
       server_seed: Map.get(params, "server_seed", ""),
       server_seed_hash: Map.get(params, "server_seed_hash", ""),
       client_seed: Map.get(params, "client_seed", ""),
       nonce: Map.get(params, "nonce", "1"),
       algorithm_version: Fairness.algorithm_version(),
       result: nil,
       error: nil
     )}
  end

  def handle_event("update_form", params, socket) do
    {:noreply,
     assign(socket,
       server_seed: Map.get(params, "server_seed", socket.assigns.server_seed),
       server_seed_hash: Map.get(params, "server_seed_hash", socket.assigns.server_seed_hash),
       client_seed: Map.get(params, "client_seed", socket.assigns.client_seed),
       nonce: Map.get(params, "nonce", socket.assigns.nonce),
       result: nil,
       error: nil
     )}
  end

  def handle_event("verify", _params, socket) do
    %{server_seed: seed_hex, server_seed_hash: hash, client_seed: client_seed, nonce: nonce_str} =
      socket.assigns

    with {:seed, {:ok, seed_binary}} <-
           {:seed, Base.decode16(String.trim(seed_hex), case: :mixed)},
         {:nonce, {n, ""}} when n >= 0 <- {:nonce, Integer.parse(String.trim(nonce_str))} do
      hash_trimmed = String.trim(hash) |> String.downcase()
      hash_ok = hash_trimmed == "" or Fairness.verify(hash_trimmed, seed_binary)

      shuffle_seed = Fairness.derive_shuffle_seed(seed_binary, String.trim(client_seed), n)
      deck = Shuffle.shuffle(Deck.new(), shuffle_seed)

      turns =
        deck
        |> Enum.drop(1)
        |> Enum.chunk_every(2)
        |> Enum.take(25)
        |> Enum.with_index(1)
        |> Enum.map(fn {[loser, winner], i} -> %{index: i, loser: loser, winner: winner} end)

      soda = hd(deck)
      hock = List.last(deck)

      result = %{
        hash_ok: hash_ok,
        hash_checked: hash_trimmed != "",
        deck: deck,
        soda: soda,
        turns: turns,
        hock: hock
      }

      {:noreply, assign(socket, result: result, error: nil)}
    else
      {:seed, :error} ->
        {:noreply,
         assign(socket,
           error:
             "Invalid server seed — must be a valid hex string (64 hex characters for a 32-byte seed).",
           result: nil
         )}

      {:nonce, _} ->
        {:noreply,
         assign(socket, error: "Invalid nonce — must be a non-negative integer.", result: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8 space-y-10">
      <div>
        <h1 class="font-serif text-3xl font-bold text-amber-400">Manual Shuffle Verifier</h1>
        <p class="mt-2 text-stone-400 leading-relaxed">
          Enter the seeds from any completed round to independently reproduce the shuffle
          and verify the card order — without trusting this server.
        </p>
      </div>

      <%!-- Input form --%>
      <form phx-change="update_form" phx-submit="verify" class="space-y-4">
        <div class="rounded-lg border border-stone-700 bg-stone-800 p-5 space-y-4">
          <div class="space-y-1">
            <label class="block text-xs font-semibold uppercase tracking-widest text-stone-400">
              Server Seed (hex)
            </label>
            <input
              type="text"
              name="server_seed"
              value={@server_seed}
              placeholder="64-character hex string revealed after the round"
              phx-debounce="300"
              class="w-full rounded border border-stone-600 bg-stone-900 px-3 py-2 font-mono text-sm text-stone-100 placeholder-stone-600 focus:border-amber-500 focus:outline-none"
            />
          </div>

          <div class="space-y-1">
            <label class="block text-xs font-semibold uppercase tracking-widest text-stone-400">
              Server Seed Hash / Commitment
              <span class="text-stone-600 normal-case">(optional — for hash verification)</span>
            </label>
            <input
              type="text"
              name="server_seed_hash"
              value={@server_seed_hash}
              placeholder="SHA-256 commitment published before the round"
              phx-debounce="300"
              class="w-full rounded border border-stone-600 bg-stone-900 px-3 py-2 font-mono text-sm text-stone-100 placeholder-stone-600 focus:border-amber-500 focus:outline-none"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="space-y-1">
              <label class="block text-xs font-semibold uppercase tracking-widest text-stone-400">
                Client Seed
              </label>
              <input
                type="text"
                name="client_seed"
                value={@client_seed}
                placeholder="Your client seed"
                phx-debounce="300"
                class="w-full rounded border border-stone-600 bg-stone-900 px-3 py-2 font-mono text-sm text-stone-100 placeholder-stone-600 focus:border-amber-500 focus:outline-none"
              />
            </div>
            <div class="space-y-1">
              <label class="block text-xs font-semibold uppercase tracking-widest text-stone-400">
                Nonce
              </label>
              <input
                type="number"
                min="0"
                name="nonce"
                value={@nonce}
                phx-debounce="300"
                class="w-full rounded border border-stone-600 bg-stone-900 px-3 py-2 font-mono text-sm text-stone-100 focus:border-amber-500 focus:outline-none"
              />
            </div>
          </div>

          <div class="space-y-1">
            <label class="block text-xs font-semibold uppercase tracking-widest text-stone-400">
              Algorithm Version
            </label>
            <input
              type="text"
              name="algorithm_version"
              value={@algorithm_version}
              disabled
              class="w-full rounded border border-stone-700 bg-stone-900 px-3 py-2 font-mono text-sm text-stone-500 cursor-not-allowed"
            />
          </div>
        </div>

        <%= if @error do %>
          <div class="rounded border border-red-700 bg-red-950 px-4 py-3 text-sm text-red-300">
            {@error}
          </div>
        <% end %>

        <button
          type="submit"
          class="rounded border border-amber-600 bg-amber-700 px-6 py-2 text-sm font-semibold uppercase tracking-widest text-stone-950 transition-colors hover:bg-amber-600"
        >
          Verify Shuffle
        </button>
      </form>

      <%!-- Results --%>
      <%= if @result do %>
        <div class="space-y-6">
          <%!-- Verification status --%>
          <div class="rounded-lg border border-stone-700 bg-stone-800 p-4 space-y-3">
            <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
              Verification Results
            </h2>
            <div class="space-y-2">
              <%= if @result.hash_checked do %>
                <.check_row
                  label="Server seed hash"
                  ok={@result.hash_ok}
                  pass_text="SHA-256(server_seed) matches commitment"
                  fail_text="Hash mismatch — server seed does not match commitment"
                />
              <% else %>
                <div class="flex items-center gap-3 text-sm">
                  <span class="rounded bg-stone-700 px-2 py-0.5 text-xs font-semibold text-stone-400">
                    —
                  </span>
                  <span class="text-stone-400">Hash check skipped (no commitment provided)</span>
                </div>
              <% end %>
              <.check_row
                label="Shuffle reproduced"
                ok={true}
                pass_text="Deck generated from seeds"
                fail_text=""
              />
            </div>
          </div>

          <%!-- Soda card --%>
          <div class="space-y-2">
            <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">Soda Card</h2>
            <p class="text-xs text-stone-500">Burned first card — counted but never bet on.</p>
            <div class="w-fit">
              <GameComponents.playing_card rank={@result.soda.rank} suit={@result.soda.suit} />
            </div>
          </div>

          <%!-- Turn sequence table --%>
          <div class="space-y-2">
            <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
              Turn Sequence (25 turns)
            </h2>
            <div class="rounded border border-stone-700 bg-stone-800 overflow-hidden">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-stone-700 text-xs uppercase tracking-widest text-stone-500">
                    <th class="px-3 py-2 text-left">#</th>
                    <th class="px-3 py-2 text-left">Banker (Loser)</th>
                    <th class="px-3 py-2 text-left">Player (Winner)</th>
                    <th class="px-3 py-2 text-left">Split?</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-stone-700/50">
                  <%= for turn <- @result.turns do %>
                    <tr class={if turn.loser.rank == turn.winner.rank, do: "bg-amber-950/20"}>
                      <td class="px-3 py-1.5 text-stone-500 font-mono text-xs">{turn.index}</td>
                      <td class="px-3 py-1.5">
                        <span class={["font-mono text-sm font-semibold", suit_color(turn.loser.suit)]}>
                          {rank_label(turn.loser.rank)}{suit_symbol(turn.loser.suit)}
                        </span>
                      </td>
                      <td class="px-3 py-1.5">
                        <span class={["font-mono text-sm font-semibold", suit_color(turn.winner.suit)]}>
                          {rank_label(turn.winner.rank)}{suit_symbol(turn.winner.suit)}
                        </span>
                      </td>
                      <td class="px-3 py-1.5">
                        <%= if turn.loser.rank == turn.winner.rank do %>
                          <span class="text-xs font-semibold text-amber-400">Split</span>
                        <% else %>
                          <span class="text-xs text-stone-600">—</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <%!-- Final three + hock --%>
          <div class="space-y-3">
            <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
              Final Three Cards
            </h2>
            <p class="text-xs text-stone-500">
              Turn 25 deals the banker and player cards from these three; the remaining card is the hock.
            </p>
            <div class="flex gap-4">
              <div class="flex flex-col items-center gap-1">
                <span class="text-xs text-stone-400">Banker</span>
                <GameComponents.playing_card
                  rank={List.last(@result.turns).loser.rank}
                  suit={List.last(@result.turns).loser.suit}
                />
              </div>
              <div class="flex flex-col items-center gap-1">
                <span class="text-xs text-stone-400">Player</span>
                <GameComponents.playing_card
                  rank={List.last(@result.turns).winner.rank}
                  suit={List.last(@result.turns).winner.suit}
                />
              </div>
              <div class="flex flex-col items-center gap-1">
                <span class="text-xs text-stone-400">Hock</span>
                <GameComponents.playing_card rank={@result.hock.rank} suit={@result.hock.suit} />
              </div>
            </div>
          </div>

          <%!-- Full deck grid --%>
          <div class="space-y-2">
            <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
              Full Shuffled Deck (52 cards)
            </h2>
            <p class="text-xs text-stone-500">
              Position 0 = soda. Positions 1–50 are dealt as 25 turns (odd = banker, even = player). Position 51 = hock.
            </p>
            <div class="rounded border border-stone-700 bg-stone-800 p-3 font-mono text-xs grid grid-cols-13 gap-1">
              <%= for {card, idx} <- Enum.with_index(@result.deck) do %>
                <div
                  title={"##{idx}: #{rank_label(card.rank)}#{suit_symbol(card.suit)}"}
                  class={[
                    "rounded px-1 py-0.5 text-center",
                    cond do
                      idx == 0 -> "bg-amber-900/40 text-amber-400"
                      idx == 51 -> "bg-stone-700 text-stone-400"
                      rem(idx, 2) == 1 -> "bg-red-950/30 text-red-400"
                      true -> "bg-green-950/30 text-green-400"
                    end
                  ]}
                >
                  {rank_label(card.rank)}{suit_symbol(card.suit)}
                </div>
              <% end %>
            </div>
            <div class="flex gap-4 text-xs text-stone-500">
              <span class="flex items-center gap-1">
                <span class="inline-block w-3 h-3 rounded bg-amber-900/60"></span> Soda
              </span>
              <span class="flex items-center gap-1">
                <span class="inline-block w-3 h-3 rounded bg-red-950/60"></span> Banker positions
              </span>
              <span class="flex items-center gap-1">
                <span class="inline-block w-3 h-3 rounded bg-green-950/60"></span> Player positions
              </span>
              <span class="flex items-center gap-1">
                <span class="inline-block w-3 h-3 rounded bg-stone-700"></span> Hock
              </span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :ok, :boolean, required: true
  attr :pass_text, :string, required: true
  attr :fail_text, :string, required: true

  defp check_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-sm">
      <span class={[
        "rounded px-2 py-0.5 text-xs font-semibold",
        if(@ok, do: "bg-green-900 text-green-400", else: "bg-red-900 text-red-400")
      ]}>
        {if @ok, do: "✓ Pass", else: "✗ Fail"}
      </span>
      <span class="font-medium text-stone-200">{@label}</span>
      <span class="text-stone-500">{if @ok, do: @pass_text, else: @fail_text}</span>
    </div>
    """
  end

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
end
