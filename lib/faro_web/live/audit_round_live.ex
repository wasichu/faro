defmodule FaroWeb.AuditRoundLive do
  use FaroWeb, :live_view

  alias Faro.Audit, as: AuditDomain
  alias Faro.FaroGame
  alias Faro.FaroGame.Serializer
  alias Faro.GameEngine.{Card, Deck, Fairness, Round, Shuffle}
  alias FaroWeb.GameComponents

  def mount(%{"id" => id}, _session, socket) do
    case load_round_data(id) do
      {:ok, round, turns, audit_record} ->
        verification = run_verification(round, turns)

        {:ok,
         assign(socket,
           page_title: "Round Audit",
           round: round,
           turns: turns,
           audit_record: audit_record,
           verification: verification,
           not_found: false
         )}

      {:not_found} ->
        {:ok,
         assign(socket,
           page_title: "Round Not Found",
           not_found: true,
           round: nil,
           turns: [],
           audit_record: nil,
           verification: nil
         )}

      {:error, _} ->
        {:ok,
         assign(socket,
           page_title: "Round Not Found",
           not_found: true,
           round: nil,
           turns: [],
           audit_record: nil,
           verification: nil
         )}
    end
  end

  def render(%{not_found: true} = assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
      <div class="rounded-lg border border-stone-700 bg-stone-800 p-8 text-center space-y-3">
        <p class="text-stone-400">Round not found.</p>
        <.link navigate={~p"/play"} class="text-amber-400 hover:underline text-sm">
          Back to play
        </.link>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-12 sm:px-6 lg:px-8 space-y-8">
      <div>
        <h1 class="font-serif text-3xl font-bold text-amber-400">Round Audit</h1>
        <p class="mt-1 font-mono text-xs text-stone-500">{@round.id}</p>
      </div>

      <%!-- Verification summary --%>
      <.verification_summary verification={@verification} />

      <%!-- Seeds & parameters --%>
      <div class="rounded-lg border border-stone-700 bg-stone-800 p-5 space-y-4">
        <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
          Fairness Parameters
        </h2>
        <dl class="space-y-3 font-mono text-xs">
          <.param_row label="Algorithm" value={@round.algorithm_version} />
          <.param_row label="Commitment (pre-game hash)" value={@round.server_seed_hash} />
          <.param_row
            label="Server Seed (revealed)"
            value={
              if @round.server_seed,
                do: Base.encode16(@round.server_seed, case: :lower),
                else: "Not yet revealed"
            }
          />
          <.param_row label="Client Seed" value={@round.client_seed} />
          <.param_row label="Nonce" value={Integer.to_string(@round.nonce)} />
          <%= if @verification && @verification.status == :complete do %>
            <.param_row label="Shuffle Seed (derived)" value={@verification.shuffle_seed_hex} />
          <% end %>
          <.param_row label="Status" value={to_string(@round.status)} />
        </dl>
      </div>

      <%!-- Soda + Hock --%>
      <%= if @verification && @verification.status == :complete do %>
        <div class="space-y-3">
          <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">Soda & Hock</h2>
          <div class="flex gap-6">
            <div class="flex flex-col items-center gap-1">
              <span class="text-xs text-stone-500">Soda (burned first card)</span>
              <GameComponents.playing_card
                rank={@round.soda_rank}
                suit={String.to_existing_atom(@round.soda_suit)}
              />
            </div>
            <%= if hock = hock_from_verification(@verification) do %>
              <div class="flex flex-col items-center gap-1">
                <span class="text-xs text-stone-500">Hock (last card, never dealt)</span>
                <GameComponents.playing_card rank={hock.rank} suit={hock.suit} />
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Turn history --%>
      <div class="space-y-3">
        <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
          Turn History ({length(@turns)} turns)
        </h2>
        <%= if @turns == [] do %>
          <p class="text-stone-500 text-sm">No turns recorded.</p>
        <% else %>
          <div class="rounded border border-stone-700 bg-stone-800 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-stone-700 text-xs uppercase tracking-widest text-stone-500">
                  <th class="px-3 py-2 text-left">#</th>
                  <th class="px-3 py-2 text-left">Banker</th>
                  <th class="px-3 py-2 text-left">Player</th>
                  <th class="px-3 py-2 text-left">Split</th>
                  <th class="px-3 py-2 text-left">Bets</th>
                  <th class="px-3 py-2 text-left">Settlements</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-stone-700/50">
                <%= for turn <- @turns do %>
                  <tr class={if turn.split, do: "bg-amber-950/20"}>
                    <td class="px-3 py-2 font-mono text-xs text-stone-500">{turn.index}</td>
                    <td class="px-3 py-2">
                      <span class={["font-mono font-semibold", suit_color(turn.loser_suit)]}>
                        {rank_label(turn.loser_rank)}{suit_symbol(turn.loser_suit)}
                      </span>
                    </td>
                    <td class="px-3 py-2">
                      <span class={["font-mono font-semibold", suit_color(turn.winner_suit)]}>
                        {rank_label(turn.winner_rank)}{suit_symbol(turn.winner_suit)}
                      </span>
                    </td>
                    <td class="px-3 py-2 text-xs">
                      <%= if turn.split do %>
                        <span class="text-amber-400 font-semibold">Split</span>
                      <% else %>
                        <span class="text-stone-600">—</span>
                      <% end %>
                    </td>
                    <td class="px-3 py-2 text-xs text-stone-400">
                      {length(turn.bets)} bet{if length(turn.bets) != 1, do: "s"}
                    </td>
                    <td class="px-3 py-2 text-xs">
                      <.settlement_summary settlements={turn.settlements} />
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <%!-- Full deck (only when verified) --%>
      <%= if @verification && @verification.status == :complete do %>
        <div class="space-y-2">
          <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
            Reproduced Shuffled Deck
          </h2>
          <p class="text-xs text-stone-500">
            Generated from the revealed server seed, client seed, and nonce.
            Amber = soda · Red = banker · Green = player · Grey = hock.
          </p>
          <div
            class="rounded border border-stone-700 bg-stone-800 p-3 font-mono text-xs grid gap-1"
            style="grid-template-columns: repeat(13, minmax(0, 1fr))"
          >
            <%= for {card, idx} <- Enum.with_index(@verification.deck) do %>
              <div
                title={"##{idx}: #{rank_label(card.rank)}#{suit_symbol(card.suit)}"}
                class={[
                  "rounded px-1 py-0.5 text-center",
                  cond do
                    idx == 0 -> "bg-amber-900/40 text-amber-400"
                    idx == 51 -> "bg-stone-700 text-stone-400"
                    rem(idx, 2) == 1 -> "bg-red-950/40 text-red-400"
                    true -> "bg-green-950/40 text-green-400"
                  end
                ]}
              >
                {rank_label(card.rank)}{suit_symbol(card.suit)}
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Verify manually link --%>
      <div class="border-t border-stone-800 pt-4 text-sm text-stone-500">
        Want to verify this independently?
        <%= if @round.server_seed do %>
          <.link
            href={
              ~p"/audit/shuffle?#{%{server_seed: Base.encode16(@round.server_seed, case: :lower), server_seed_hash: @round.server_seed_hash, client_seed: @round.client_seed, nonce: @round.nonce}}"
            }
            target="_blank"
            class="text-amber-400 hover:underline ml-1"
          >
            Open in manual verifier →
          </.link>
        <% else %>
          <.link href={~p"/audit/shuffle"} target="_blank" class="text-amber-400 hover:underline ml-1">
            Use the manual shuffle verifier
          </.link>
          <span class="ml-1">(seeds available after round finishes)</span>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Sub-components
  # ---------------------------------------------------------------------------

  attr :verification, :map, required: true

  defp verification_summary(%{verification: nil} = assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-4 text-sm text-stone-400">
      Verification data unavailable.
    </div>
    """
  end

  defp verification_summary(%{verification: %{status: :incomplete}} = assigns) do
    ~H"""
    <div class="rounded-lg border border-amber-700/40 bg-amber-950/20 p-4 space-y-1">
      <p class="text-sm font-semibold text-amber-400">Round Not Finished</p>
      <p class="text-sm text-stone-400">{@verification.message}</p>
    </div>
    """
  end

  defp verification_summary(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-700 bg-stone-800 p-5 space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-bold uppercase tracking-widest text-amber-400">
          Verification
        </h2>
        <span class={[
          "rounded px-3 py-1 text-xs font-bold uppercase tracking-widest",
          if(@verification.overall,
            do: "bg-green-900 text-green-400",
            else: "bg-red-900 text-red-400"
          )
        ]}>
          {if @verification.overall, do: "✓ All Checks Pass", else: "✗ Verification Failed"}
        </span>
      </div>
      <div class="space-y-2">
        <.check_row
          label="Seed hash"
          ok={@verification.hash_ok}
          pass_text="SHA-256(server_seed) = commitment"
          fail_text="Hash does not match commitment"
        />
        <.check_row
          label="Shuffle reproduction"
          ok={@verification.deck_ok}
          pass_text="Deck reproduced from seeds matches stored deck"
          fail_text="Reproduced deck does not match stored deck"
        />
        <.check_row
          label="Soda card"
          ok={@verification.soda_ok}
          pass_text="deck[0] matches stored soda"
          fail_text="Soda card mismatch"
        />
        <.check_row
          label="Card order"
          ok={@verification.cards_ok}
          pass_text="All 25 turns match deck positions"
          fail_text="Turn card mismatch detected"
        />
        <.check_row
          label="Settlements"
          ok={@verification.settlements_ok}
          pass_text="All bet settlements match engine replay"
          fail_text="Settlement mismatch detected"
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp param_row(assigns) do
    ~H"""
    <div class="space-y-0.5">
      <dt class="text-stone-500 font-sans text-[10px] uppercase tracking-wider">{@label}</dt>
      <dd class="text-stone-300 break-all">{@value}</dd>
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
        "flex-shrink-0 rounded px-2 py-0.5 text-xs font-semibold",
        if(@ok, do: "bg-green-900 text-green-400", else: "bg-red-900 text-red-400")
      ]}>
        {if @ok, do: "✓", else: "✗"}
      </span>
      <span class="font-medium text-stone-200">{@label}</span>
      <span class="text-stone-500 text-xs">{if @ok, do: @pass_text, else: @fail_text}</span>
    </div>
    """
  end

  attr :settlements, :list, required: true

  defp settlement_summary(%{settlements: []} = assigns) do
    ~H"""
    <span class="text-stone-600">—</span>
    """
  end

  defp settlement_summary(assigns) do
    ~H"""
    <span class="text-stone-400">
      {Enum.map_join(@settlements, ", ", fn s ->
        outcome = s["outcome"] || "?"
        net = s["net"] || 0
        prefix = if net > 0, do: "+", else: ""
        "#{outcome} #{prefix}#{net}"
      end)}
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_round_data(id) do
    with {:ok, round} <- FaroGame.get_round(id) do
      turns = FaroGame.list_turns_for_round!(id)

      audit_record =
        case AuditDomain.get_audit_record_by_round(id) do
          {:ok, rec} -> rec
          _ -> nil
        end

      {:ok, round, turns, audit_record}
    else
      {:error, %Ash.Error.Query.NotFound{}} -> {:not_found}
      {:error, e} -> {:error, e}
    end
  end

  defp run_verification(round, turns) do
    cond do
      round.status != :finished ->
        %{
          status: :incomplete,
          message: "Round not yet finished — server seed has not been revealed."
        }

      round.server_seed == nil ->
        %{status: :incomplete, message: "Server seed not yet revealed."}

      true ->
        decoded_deck = Serializer.decode_deck(round.shuffled_deck)
        soda = %Card{rank: round.soda_rank, suit: String.to_existing_atom(round.soda_suit)}

        hash_ok = Fairness.verify(round.server_seed_hash, round.server_seed)

        shuffle_seed =
          Fairness.derive_shuffle_seed(round.server_seed, round.client_seed, round.nonce)

        shuffle_seed_hex = Base.encode16(shuffle_seed, case: :lower)
        reproduced = Shuffle.shuffle(Deck.new(), shuffle_seed)
        deck_ok = reproduced == decoded_deck

        soda_ok = decoded_deck != [] and hd(decoded_deck) == soda

        {cards_ok, settlements_ok} = replay_and_verify(decoded_deck, turns)

        %{
          status: :complete,
          hash_ok: hash_ok,
          deck_ok: deck_ok,
          soda_ok: soda_ok,
          cards_ok: cards_ok,
          settlements_ok: settlements_ok,
          overall: hash_ok && deck_ok && soda_ok && cards_ok && settlements_ok,
          deck: decoded_deck,
          shuffle_seed_hex: shuffle_seed_hex
        }
    end
  end

  defp replay_and_verify(decoded_deck, turns) do
    engine_round = Round.new(decoded_deck)

    {_, cards_ok, settlements_ok} =
      Enum.reduce(turns, {engine_round, true, true}, fn turn, {eng_round, cards_acc, sett_acc} ->
        decoded_bets = Enum.map(turn.bets, &Serializer.decode_bet/1)
        {completed, new_round} = Round.deal_turn(eng_round, decoded_bets)

        cards_match =
          completed.loser.rank == turn.loser_rank &&
            to_string(completed.loser.suit) == turn.loser_suit &&
            completed.winner.rank == turn.winner_rank &&
            to_string(completed.winner.suit) == turn.winner_suit

        stored_settlements = Enum.map(turn.settlements, &Serializer.decode_settlement/1)

        settlements_match =
          length(stored_settlements) == length(completed.settlements) &&
            Enum.all?(Enum.zip(stored_settlements, completed.settlements), fn {s, c} ->
              s.outcome == c.outcome && s.net == c.net
            end)

        {new_round, cards_acc && cards_match, sett_acc && settlements_match}
      end)

    {cards_ok, settlements_ok}
  end

  defp hock_from_verification(%{status: :complete, deck: deck}) when length(deck) == 52,
    do: List.last(deck)

  defp hock_from_verification(_), do: nil

  defp rank_label(1), do: "A"
  defp rank_label(11), do: "J"
  defp rank_label(12), do: "Q"
  defp rank_label(13), do: "K"
  defp rank_label(n), do: Integer.to_string(n)

  defp suit_symbol(:spades), do: "♠"
  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"
  defp suit_symbol(s) when is_binary(s), do: suit_symbol(String.to_existing_atom(s))

  defp suit_color("hearts"), do: "text-rose-400"
  defp suit_color("diamonds"), do: "text-rose-400"
  defp suit_color("spades"), do: "text-stone-200"
  defp suit_color("clubs"), do: "text-stone-200"
end
