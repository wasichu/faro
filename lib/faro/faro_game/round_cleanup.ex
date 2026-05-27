defmodule Faro.FaroGame.RoundCleanup do
  @moduledoc """
  Run module for the `cleanup_abandoned_rounds` scheduled action.

  Deletes game rounds that started but never completed (status :dealing or
  :call_the_turn, `updated_at` older than the configured retention window).
  Cascade deletes remove turns and the audit record; ledger entries that
  reference the round have their `round_id` set to NULL to preserve wallet
  accounting history.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query
  require Logger

  @impl true
  def run(_input, _opts, _context) do
    hours = get_in(Application.get_env(:faro, :cleanup, []), [:round_retention_hours]) || 2
    threshold = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    result =
      Faro.FaroGame.Round
      |> Ash.Query.filter(status in [:dealing, :call_the_turn] and updated_at < ^threshold)
      |> Ash.bulk_destroy(:destroy, %{}, authorize?: false, return_errors?: true)

    case result do
      %Ash.BulkResult{status: :success} ->
        Logger.info("[Cleanup] Abandoned round cleanup complete (threshold: #{hours}h)")
        :ok

      %Ash.BulkResult{status: :partial_success, error_count: n, errors: errors} ->
        Logger.warning("[Cleanup] Round cleanup partial: #{n} error(s): #{inspect(errors)}")

        :ok

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("[Cleanup] Round cleanup failed: #{inspect(errors)}")
        {:error, errors}
    end
  end
end
