# Faro — Operations

## Production deployment

Use **Actions → Deploy production → Run workflow**, selecting `main`. The workflow
waits for successful push CI for that exact commit, then deploys to
`faro-amefvg`. Production deployments run one at a time and are not cancelled by
new CI runs. Deploying another branch is skipped.

The deployment job uses GitHub's `production` environment, so GitHub records its
commit, app URL, and success/failure status automatically. Fly images carry the
`git-<full commit SHA>` tag and the `org.opencontainers.image.revision` label.
Direct terminal deployments bypass this reporting; use the workflow to keep
GitHub's production history current.

The workflow requires a `FLY_API_TOKEN` Actions secret scoped to `faro-amefvg`.
Create or rotate it without printing the credential:

```sh
set -o pipefail
flyctl tokens create deploy --app faro-amefvg --name github-actions-production --expiry 2160h |
  gh secret set FLY_API_TOKEN --repo wasichu/faro
```

This token expires after 90 days; rotate it before expiry. The workflow and
flyctl versions are pinned in `.github/workflows/deploy.yml`.

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

## Integrity migration

The `harden_game_integrity` migration installs ash-functions v7's `ash_required/2`
and enforces one turn per `(round_id, index)` and one wallet per non-null session.
It does not delete or merge existing records. If a deployment database already
contains duplicate keys, reconcile those records before running the migration;
PostgreSQL will reject the unique index rather than silently discard history.
The rollback removes the indexes and retains the compatible Ash function.

A committed turn refreshes both session and round activity timestamps, so cleanup
uses gameplay activity rather than only the session's creation time.
