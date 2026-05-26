We are building a Phoenix LiveView application called Faro.

The project is:
- a historically accurate faro simulator
- FTC-only initially (fake tokens only)
- later integrated with Bitcoin Core regtest for wallet experimentation
- not intended to be a production gambling platform

Tech stack:
- Elixir
- OTP
- Phoenix
- LiveView
- PostgreSQL
- Ash
- AshPostgres
- AshAuthentication
- Oban
- StreamData for property testing

Goals:
- pure deterministic game engine
- provably fair shuffle and audit verification
- append-only ledger architecture
- clean separation between game engine and persistence
- future regtest Bitcoin integration through adapter behaviour

Tasks:

1. Set up the project structure cleanly.

Namespaces:
- FaroWeb
- Faro.GameEngine
- Faro.Accounts
- Faro.Wallets
- Faro.FaroGame
- Faro.Bitcoin
- Faro.Audit

2. Configure:
- Ash
- AshPostgres
- AshAuthentication
- Oban
- StreamData

3. Create empty Ash domains/modules only.
No resource attributes/actions yet unless trivial.

4. Create pure engine placeholder modules under Faro.GameEngine:
- Card
- Deck
- Fairness
- Shuffle
- Round
- Turn
- Bet
- Settlement
- Casekeeper
- Audit

5. Add module docs explaining responsibilities and architectural boundaries.

Requirements:
- Faro.GameEngine must remain pure Elixir.
- No Repo calls inside Faro.GameEngine.
- No Ash resources inside Faro.GameEngine.
- No LiveView dependencies inside Faro.GameEngine.
- No process state in Faro.GameEngine.

6. Create initial docs/architecture.md explaining:
- overall architecture
- FTC-only v1
- future Bitcoin regtest support
- pure engine philosophy
- ledger philosophy
- provably fair design goals
