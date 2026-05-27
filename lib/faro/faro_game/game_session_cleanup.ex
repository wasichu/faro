defmodule Faro.FaroGame.GameSessionCleanup do
  @moduledoc """
  Run module for the `cleanup_abandoned_sessions` scheduled action.

  Deletes anonymous FTC game sessions that have been inactive (status :active,
  `updated_at` older than the configured retention window). Cascade deletes
  remove the session's rounds, turns, audit records, wallet, and ledger
  entries automatically.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query
  require Logger

  @impl true
  def run(_input, _opts, _context) do
    hours = get_in(Application.get_env(:faro, :cleanup, []), [:session_retention_hours]) || 24
    threshold = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    result =
      Faro.FaroGame.GameSession
      |> Ash.Query.filter(status == :active and updated_at < ^threshold)
      |> Ash.bulk_destroy(:destroy, %{}, authorize?: false, return_errors?: true)

    case result do
      %Ash.BulkResult{status: :success} ->
        Logger.info("[Cleanup] Abandoned session cleanup complete (threshold: #{hours}h)")
        :ok

      %Ash.BulkResult{status: :partial_success, error_count: n, errors: errors} ->
        Logger.warning("[Cleanup] Session cleanup partial: #{n} error(s): #{inspect(errors)}")

        :ok

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("[Cleanup] Session cleanup failed: #{inspect(errors)}")
        {:error, errors}
    end
  end
end
