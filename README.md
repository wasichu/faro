# Faro

A historically accurate Faro card-game simulator built with Phoenix LiveView and Ash Framework.

Faro dominated American gambling halls for nearly a century. When honestly dealt it offered unusually favorable odds. Its house edge came almost entirely from doublets, when both revealed cards share a rank. This version lets you play the game, inspect each round, and verify its shuffle.

**[Try Faro now](https://faro.slowinput.org)**

## Features

- **Historically accurate rules**: copper bets, doublets, call-the-turn, high card bar, and the full casekeeper
- **Provably fair shuffles**: HMAC-SHA256 counter-mode PRNG; server commits to a seed hash before the round and reveals it after, so every shuffle is independently verifiable
- **Pure game engine**: `Faro.GameEngine` contains zero I/O, no process state, no Ash calls; every function is a pure data transformation
- **Append-only ledger**: all FTC balance changes produce ledger entries; the cached settled balance is reconciled with their sum
- **Audit transcripts**: one record per completed round, containing everything needed to reproduce the shuffle and verify every turn
- **Background maintenance**: Oban jobs clean up abandoned sessions and rounds on a configurable schedule

FTC (Fake Token Currency) is used throughout v1. No real money, no payment processing.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Elixir / OTP |
| Web | Phoenix 1.8, LiveView |
| Persistence | Ash 3.x, AshPostgres, PostgreSQL |
| Auth | AshAuthentication dependency; anonymous play, no configured strategies |
| Background jobs | Oban, AshOban |
| Tests | ExUnit, StreamData (property-based), Playwright (desktop/mobile) |
| Assets | Tailwind CSS, esbuild |

Deployed on [Fly.io](https://fly.io) with [Neon](https://neon.tech) PostgreSQL.

## Prerequisites

- [mise](https://mise.jdx.dev/) (installs the Elixir, Erlang, Node.js, and just versions pinned in `mise.toml`)
- Docker (for the PostgreSQL container)

## Development Setup

```bash
# Trust the project config and install the pinned tools
mise trust
mise install

# Start PostgreSQL, install dependencies, create/migrate the database, and build assets
mise exec -- just setup

# Start PostgreSQL + Phoenix in one step
mise exec -- just dev
```

Visit [localhost:4000](http://localhost:4000).

With mise activated in your shell, use `just` directly. Run `just --list` for
all commands. To start the services separately:

```bash
just db-up             # PostgreSQL only (waits for readiness)
mix phx.server         # Phoenix only
```

Or with an IEx shell:

```bash
just console
```

### Database

The `docker-compose.yml` defines a single PostgreSQL 18 service on port 5432.
If another project uses that port, export `FARO_DB_PORT=55432` before running
setup, development, or tests. Compose and the development/test configs share
this setting. The database binds only to localhost.

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
mise exec -- just test
# Or a specific test:
mise exec -- just test test/faro/game_engine/deck_test.exs
```

Uses a separate `faro_test` database; migrations run automatically. The suite includes unit tests, integration tests against a real database, and property-based tests of the game engine.

Browser checks use their own `faro_browser_test` database, so they do not leave
records in the ExUnit database. They launch and stop a dedicated Phoenix server
on port 4793; set `PLAYWRIGHT_PORT` if that port is occupied.

```bash
mise exec -- just browser-setup   # Install the locked Chromium version once
mise exec -- just browser-check   # Run desktop and mobile journeys
mise exec -- just browser-report  # Open the HTML report
```

The journeys cover client-seed forms and commitment preservation, wager amounts,
repeat bets, all 25 turns, desktop drag/drop and mobile final-card selection,
sorted card pools, persisted audits, the manual verifier, nonce overflow,
horizontal layout overflow, and browser JavaScript errors. Screenshots and
failure traces are saved in `test-results/` and `playwright-report/`.


## Pre-commit Checks

```bash
mise exec -- just check
```

Compiles with warnings-as-errors, removes unused deps, formats code, and runs the full test suite. Run this before every push.

## Dependency Updates and CI

`mise.toml` pins the local and CI toolchain; the Dockerfile uses matching Elixir/OTP
and Node.js versions. DaisyUI and topbar are locked in `package-lock.json`;
Tailwind and esbuild binary versions are pinned in `config/config.exs`.

```bash
mise exec -- just outdated  # Check Hex and npm packages
mise exec -- just update    # Update lockfiles within constraints, then check and build assets
mise exec -- just ci        # Check formatting, lockfile, unit/browser tests, and assets
mise exec -- just release   # Build production assets and a release
```

GitHub Actions installs Chromium, runs `just ci` against PostgreSQL 18, saves browser reports, builds a production release,
and builds the Docker image on pushes and pull requests.
[Renovate](https://github.com/apps/renovate) is configured for weekly dependency
PRs covering Hex packages, mise tools, Docker images, GitHub Actions, Heroicons,
and asset binaries. The hosted app already has access to `wasichu/faro`; merge the config
to the default branch for this policy to take effect. See [maintenance notes](.github/renovate.md)
for setup and the remaining upstream Assent constraint.

## Architecture

The codebase is divided into strict layers with no reverse dependencies:

```
FaroWeb → FaroGame, Accounts, Wallets, Audit
FaroGame → GameEngine, Wallets, Audit
GameEngine → (pure functions only)
```

**`Faro.GameEngine`**: pure Elixir modules: `Card`, `Deck`, `Shuffle`, `Fairness`, `Round`, `Turn`, `Bet`, `Settlement`, `Casekeeper`, `Audit`. No database, no processes, and no randomness. Callers supply seeds.

**`Faro.FaroGame`**: Ash resources for game persistence (`GameSession`, `Round`, `Turn`, `Wallet`, `LedgerEntry`, `AuditRecord`). Coordinates lifecycle and calls the engine.

**`FaroWeb`**: five LiveViews: Home, Play, Rules, Philosophy, Audit.

For full details see [`docs/architecture.md`](docs/architecture.md), [`docs/schema.md`](docs/schema.md), and [`docs/operations.md`](docs/operations.md).
