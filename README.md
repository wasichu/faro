# Faro

A historically accurate Faro card-game simulator built with Phoenix LiveView and Ash Framework.

Faro dominated American gambling halls for nearly a century. When honestly dealt it offered unusually favorable odds — a house edge derived almost entirely from doublets (when both revealed cards share a rank). This project recreates the game with a focus on transparency, auditability, and provably fair mechanics rather than modern casino design.

## Features

- **Historically accurate rules** — copper bets, doublets, call-the-turn, high card bar, and the full casekeeper
- **Provably fair shuffles** — HMAC-SHA256 counter-mode PRNG; server commits to a seed hash before the round and reveals it after, so every shuffle is independently verifiable
- **Pure game engine** — `Faro.GameEngine` contains zero I/O, no process state, no Ash calls; every function is a pure data transformation
- **Append-only ledger** — all FTC balance changes are permanent ledger entries; no mutable balance fields
- **Audit transcripts** — one record per completed round, containing everything needed to reproduce the shuffle and verify every turn
- **Background maintenance** — Oban jobs clean up abandoned sessions and rounds on a configurable schedule

FTC (Fake Token Currency) is used throughout v1. No real money, no payment processing.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Elixir / OTP |
| Web | Phoenix 1.8, LiveView |
| Persistence | Ash 3.x, AshPostgres, PostgreSQL |
| Auth | AshAuthentication |
| Background jobs | Oban, AshOban |
| Tests | ExUnit, StreamData (property-based) |
| Assets | Tailwind CSS, esbuild |

## Prerequisites

- Elixir / Erlang (see `.tool-versions` or `mix.exs` for version constraints)
- Docker (for the PostgreSQL container)

## Development Setup

```bash
# Install dependencies and create/migrate the database
mix setup

# Start PostgreSQL + Phoenix in one step
mix dev
```

Visit [localhost:4000](http://localhost:4000).

Run them separately if preferred:

```bash
docker compose up -d   # PostgreSQL only
mix phx.server         # Phoenix only
```

Or with an IEx shell:

```bash
mix docker.up
iex -S mix phx.server
```

### Database

The `docker-compose.yml` defines a single PostgreSQL 18 service on port 5432.

| Setting  | Value      |
|---|---|
| User     | `postgres` |
| Password | `postgres` |
| Database | `faro_dev` |

To reset:

```bash
mix ecto.reset
```

## Tests

```bash
mix test
```

Uses a separate `faro_test` database; migrations run automatically. The suite includes unit tests, integration tests against a real database, and property-based tests of the game engine.

## Pre-commit Checks

```bash
mix precommit
```

Compiles with warnings-as-errors, removes unused deps, formats code, and runs the full test suite. Run this before every push.

## Architecture

The codebase is divided into strict layers with no reverse dependencies:

```
FaroWeb → FaroGame, Accounts, Wallets, Audit
FaroGame → GameEngine, Wallets, Audit
GameEngine → (nothing — pure functions only)
```

**`Faro.GameEngine`** — pure Elixir modules: `Card`, `Deck`, `Shuffle`, `Fairness`, `Round`, `Turn`, `Bet`, `Settlement`, `Casekeeper`, `Audit`. No database, no processes, no randomness — callers supply seeds.

**`Faro.FaroGame`** — Ash resources for game persistence (`GameSession`, `Round`, `Turn`, `Wallet`, `LedgerEntry`, `AuditRecord`). Coordinates lifecycle and calls the engine.

**`FaroWeb`** — five LiveViews: Home, Play, Rules, Philosophy, Audit.

For full details see [`docs/architecture.md`](docs/architecture.md), [`docs/schema.md`](docs/schema.md), and [`docs/operations.md`](docs/operations.md).
