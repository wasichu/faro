# Faro — Operations

## Background Jobs (Oban)

Faro uses [Oban](https://github.com/sorentwo/oban) for background job processing, configured via `AshOban`. All jobs are registered through the `ash_domains` list in `application.ex`.

### Queues

| Queue | Concurrency | Purpose |
|---|---|---|
| `default` | 10 | General-purpose jobs (future use) |
| `maintenance` | 5 | Periodic cleanup and retention jobs |

---

## Cleanup / Retention Policy

Two scheduled jobs run periodically to delete stale records. Both are idempotent and safe to run repeatedly.

### Abandoned Session Cleanup

**Schedule:** Hourly (`0 * * * *`)  
**Worker:** `Faro.FaroGame.GameSessionCleanup`  
**Action:** `Faro.FaroGame.GameSession.cleanup_abandoned_sessions`

Deletes `GameSession` records with `status: :active` whose `updated_at` is older than the session retention threshold. These are anonymous FTC sessions whose browser tab was closed or the connection was lost before the session was explicitly ended.

**Cascade effect:** Deleting a session also removes:
- All associated `game_rounds`
- All turns (`game_turns`) within those rounds
- All audit records (`audit_records`) for those rounds
- The session's `wallet`
- All `ledger_entries` for that wallet

### Abandoned Round Cleanup

**Schedule:** Every 30 minutes (`*/30 * * * *`)  
**Worker:** `Faro.FaroGame.RoundCleanup`  
**Action:** `Faro.FaroGame.Round.cleanup_abandoned_rounds`

Deletes `Round` records with `status` of `:dealing` or `:call_the_turn` whose `updated_at` is older than the round retention threshold. These are rounds that were started but the deal was never completed.

**Cascade effect:** Deleting a round also removes:
- All associated `game_turns`
- The `audit_record` for that round
- `ledger_entries.round_id` is set to `NULL` (entries are preserved for wallet accounting)

---

## Retention Configuration

Retention thresholds are configured in `config/config.exs` (or environment-specific overrides):

```elixir
config :faro, :cleanup,
  session_retention_hours: 24,   # default: 24 hours
  round_retention_hours: 2       # default: 2 hours
```

Override in `config/prod.exs` or via runtime config as needed.

---

## Cascade Reference Summary

The following DB-level `ON DELETE` rules ensure referential integrity:

| Child Table | Parent | On Parent Delete |
|---|---|---|
| `game_rounds` | `game_sessions` | `CASCADE` |
| `game_turns` | `game_rounds` | `CASCADE` |
| `audit_records` | `game_rounds` | `CASCADE` |
| `wallets` | `game_sessions` | `CASCADE` |
| `ledger_entries` | `wallets` | `CASCADE` |
| `ledger_entries.round_id` | `game_rounds` | `SET NULL` |
