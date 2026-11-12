defmodule Faro.FaroGame.DealTurn do
  @moduledoc "Replays persisted state and commits a turn and all accounting in one transaction."
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Faro.FaroGame
  alias Faro.FaroGame.{Serializer, Wallet}
  alias Faro.GameEngine.{Audit, CallTheTurnBet, Deck, Fairness, Round, Shuffle, Wager}

  @impl true
  def run(%{arguments: %{params: params}}, _opts, _context) do
    deal(params)
  end

  defp deal(%{
         round_id: round_id,
         wallet_id: wallet_id,
         bets: bets,
         server_seed: seed,
         expected_index: index
       }) do
    with {:ok, db_round} <- locked(FaroGame.Round, round_id),
         {:ok, wallet} <- locked(Wallet, wallet_id),
         true <-
           db_round.game_session_id != nil and db_round.game_session_id == wallet.game_session_id,
         true <- db_round.status != :finished,
         true <- Fairness.verify(db_round.server_seed_hash, seed),
         expected_deck =
           Shuffle.shuffle(
             Deck.new(),
             Fairness.derive_shuffle_seed(seed, db_round.client_seed, db_round.nonce)
           ),
         true <- Serializer.encode_deck(expected_deck) == db_round.shuffled_deck,
         {:ok, turns} <- FaroGame.list_turns_for_round(round_id),
         true <- index == length(turns) + 1,
         {:ok, round} <- replay(db_round, turns),
         true <- round.phase == db_round.status,
         true <- valid_bets?(bets, round, wallet.balance_sats),
         {turn, next_round} = Round.deal_turn(round, bets),
         {:ok, audit} <- completed_audit(db_round, next_round, seed),
         {:ok, _} <- FaroGame.create_turn(turn_attrs(round_id, turn)),
         balance = wallet.balance_sats + Enum.sum(Enum.map(turn.settlements, & &1.net)),
         {:ok, wallet} <-
           Wallet.record_turn(wallet, turn, balance, round_id: round_id, turn_index: turn.index),
         {:ok, _} <- FaroGame.advance_round_turn(db_round, round_attrs(next_round, seed)),
         :ok <- save_audit(round_id, audit),
         {:ok, session} <- FaroGame.get_session(db_round.game_session_id),
         {:ok, _} <- FaroGame.record_session_activity(session) do
      {:ok, %{turn: turn, round: next_round, wallet: wallet, audit: audit}}
    else
      false -> {:error, "Invalid, unfunded, or stale game turn"}
      {:error, error} -> {:error, error}
    end
  end

  defp deal(_), do: {:error, "Invalid game turn parameters"}

  defp locked(resource, id) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, "Game record no longer exists"}
      result -> result
    end
  end

  defp replay(db_round, turns) do
    Enum.reduce_while(
      turns,
      {:ok, Round.new(Serializer.decode_deck(db_round.shuffled_deck))},
      fn stored, {:ok, round} ->
        {turn, next} = Round.deal_turn(round, Enum.map(stored.bets, &Serializer.decode_bet/1))
        expected = turn_attrs(db_round.id, turn)

        if Map.take(stored, Map.keys(expected)) == expected do
          {:cont, {:ok, next}}
        else
          {:halt, {:error, "Stored turn failed replay verification"}}
        end
      end
    )
  end

  defp valid_bets?(bets, round, balance) when is_list(bets) do
    length(bets) <= 14 and Enum.all?(bets, &Wager.valid?/1) and
      Enum.sum(Enum.map(bets, & &1.amount)) <= balance and
      Enum.all?(bets, fn bet ->
        case round.phase do
          :dealing ->
            not match?(%CallTheTurnBet{}, bet)

          :call_the_turn ->
            length(bets) == 1 and match?(%CallTheTurnBet{}, bet) and
              length(Enum.uniq_by(round.deck, & &1.rank)) > 1

          _ ->
            false
        end
      end)
  end

  defp valid_bets?(_, _, _), do: false

  defp completed_audit(db_round, %Round{phase: :finished} = round, seed) do
    audit =
      Audit.from_round(
        round,
        db_round.server_seed_hash,
        seed,
        db_round.client_seed,
        db_round.nonce,
        Serializer.decode_deck(db_round.shuffled_deck)
      )
      |> Audit.verify_full()

    if audit.verified?, do: {:ok, audit}, else: {:error, "Round verification failed"}
  end

  defp completed_audit(_, _, _), do: {:ok, nil}

  defp round_attrs(%Round{phase: :finished}, seed), do: %{status: :finished, server_seed: seed}
  defp round_attrs(round, _seed), do: %{status: round.phase}

  defp turn_attrs(round_id, turn) do
    %{
      round_id: round_id,
      index: turn.index,
      loser_rank: turn.loser.rank,
      loser_suit: to_string(turn.loser.suit),
      winner_rank: turn.winner.rank,
      winner_suit: to_string(turn.winner.suit),
      split: turn.split?,
      bets: Enum.map(turn.bets, &Serializer.encode_bet/1),
      settlements: Enum.map(turn.settlements, &Serializer.encode_settlement/1)
    }
  end

  defp save_audit(_, nil), do: :ok

  defp save_audit(round_id, audit) do
    attrs = %{
      round_id: round_id,
      algorithm_version: audit.algorithm_version,
      server_commitment: audit.server_commitment,
      server_seed: audit.server_seed,
      client_seed: audit.client_seed,
      nonce: audit.nonce,
      verified: audit.verified?,
      shuffled_deck: Serializer.encode_deck(audit.shuffled_deck),
      soda: Serializer.encode_card(audit.soda),
      turns: Enum.map(audit.turns, &Serializer.encode_audit_turn/1)
    }

    case Faro.Audit.create_audit_record(attrs) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
