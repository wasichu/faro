Implement the first persistence layer for Faro using Ash and AshPostgres.

Goals:
- persist gameplay state
- persist audit/fairness data
- support replaying rounds and turns later
- do NOT implement wallets or ledger yet
- do NOT add BTC logic yet
- do NOT add Oban workflows yet

Create Ash domains/resources for:
- GameSession
- Round
- Turn
- Bet
- Settlement
- AuditRecord

Requirements:

1. Architectural boundaries
- Faro.GameEngine must remain pure and independent
- Faro.GameEngine must not depend on:
  - Ash
  - Repo
  - LiveView
  - Oban
  - Bitcoin
- Ash resources persist outputs from the GameEngine

2. Persistence modeling
Persist:
- fairness data
- server_seed_hash
- client_seed
- nonce
- algorithm_version
- revealed cards
- settlements
- call-the-turn results
- soda card
- audit payloads

3. Relationships
- GameSession has many Rounds
- Round has many Turns
- Turn has many Bets
- Turn has many Settlements
- Round has one AuditRecord

4. Storage format
Use pragmatic/simple storage:
- embedded JSON/maps where reasonable
- integer sats for all amounts
- avoid premature normalization

5. Add migrations and tests
- Ash resource tests
- create/query/replay tests
- verify persisted rounds can reconstruct gameplay state

6. Do not build:
- wallet persistence
- balances
- ledger entries
- auth flows
- BTC logic
- admin tools
