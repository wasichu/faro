Step 9: Add basic Oban maintenance jobs.

Goal:
Introduce safe background maintenance before any Bitcoin-related work.

Focus:
- cleanup
- retention
- operational hygiene
- no UI changes

Requirements:
- add an Oban cleanup worker for abandoned anonymous FTC sessions
- add cleanup for stale unfinished game sessions/rounds if appropriate
- make retention periods configurable
- jobs must be idempotent
- jobs must be safe to run repeatedly
- add tests for cleanup behavior
- add logging where useful
- document the cleanup policy in docs/architecture.md or docs/operations.md

Suggested cleanup targets:
- anonymous FTC sessions inactive past retention threshold
- unfinished game sessions older than retention threshold
- abandoned rounds that never completed
- temporary/debug audit payloads if such records exist

Do not add:
- BTC
- Bitcoin auth
- deposits
- withdrawals
- PSBT flows
- new UI
- gameplay behavior changes
