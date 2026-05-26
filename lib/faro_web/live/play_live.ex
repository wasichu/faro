defmodule FaroWeb.PlayLive do
  use FaroWeb, :live_view

  @mock_balance 1_000_000

  @mock_bets %{
    7 => %{amount: 5_000, copper?: false},
    12 => %{amount: 2_000, copper?: true},
    1 => %{amount: 10_000, copper?: false},
    9 => %{amount: 1_000, copper?: false}
  }

  @mock_high_card_bet %{amount: 3_000, copper?: false}

  @mock_banker_card %{rank: 7, suit: :clubs}
  @mock_player_card %{rank: 12, suit: :hearts}

  @mock_recent_turns [
    %{
      index: 5,
      loser: %{rank: 7, suit: :clubs},
      winner: %{rank: 12, suit: :hearts},
      split?: false
    },
    %{
      index: 4,
      loser: %{rank: 3, suit: :diamonds},
      winner: %{rank: 9, suit: :spades},
      split?: false
    },
    %{index: 3, loser: %{rank: 5, suit: :hearts}, winner: %{rank: 5, suit: :clubs}, split?: true},
    %{
      index: 2,
      loser: %{rank: 1, suit: :diamonds},
      winner: %{rank: 11, suit: :clubs},
      split?: false
    },
    %{
      index: 1,
      loser: %{rank: 8, suit: :spades},
      winner: %{rank: 2, suit: :diamonds},
      split?: false
    }
  ]

  @mock_casekeeper %{
    1 => 1,
    2 => 1,
    3 => 1,
    4 => 0,
    5 => 2,
    6 => 0,
    7 => 1,
    8 => 1,
    9 => 1,
    10 => 0,
    11 => 1,
    12 => 0,
    13 => 0
  }

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Play",
       balance: @mock_balance,
       bets: @mock_bets,
       high_card_bet: @mock_high_card_bet,
       banker_card: @mock_banker_card,
       player_card: @mock_player_card,
       recent_turns: @mock_recent_turns,
       casekeeper: @mock_casekeeper,
       phase: :dealing,
       turn_number: 5
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-green-950 min-h-full">
      <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-3">
            <span class="rounded border border-stone-700 bg-stone-800 px-3 py-1 text-xs uppercase tracking-widest text-stone-400">
              {phase_label(@phase)}
            </span>
            <span class="text-xs text-stone-500">Turn {@turn_number} of 24</span>
          </div>
          <.balance_display balance_sats={@balance} />
        </div>

        <.faro_board bets={@bets} high_card_bet={@high_card_bet} />

        <div class="grid gap-4 lg:grid-cols-2">
          <.current_turn_display
            banker_card={@banker_card}
            player_card={@player_card}
            turn_number={@turn_number}
            split?={false}
          />
          <.recent_turns_list turns={@recent_turns} />
        </div>

        <.casekeeper_display seen={@casekeeper} />

        <.call_the_turn_area phase={@phase} />
      </div>
    </div>
    """
  end

  defp phase_label(:dealing), do: "Dealing"
  defp phase_label(:call_the_turn), do: "Call the Turn"
  defp phase_label(:finished), do: "Finished"
end
