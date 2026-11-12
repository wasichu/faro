set positional-arguments

# List development commands.
default:
    @just --list

# Bootstrap the database and application after mise install.
setup: db-up
    mix local.hex --force
    mix local.rebar --force
    npm ci
    mix setup

# Start PostgreSQL and wait until it accepts connections.
db-up:
    docker compose up -d --wait

# Stop the project's database, preserving its volume.
db-down:
    docker compose down

# Start PostgreSQL and Phoenix with live reloading.
dev: db-up
    mix phx.server

# Start PostgreSQL and Phoenix in IEx.
console: db-up
    iex -S mix phx.server

# Run tests; accepts a file, line number, or Mix test options.
test *args:
    mix test "$@"

format:
    mix format

# Run the required project checks.
check:
    mix precommit

# Verify formatting, lockfile, source, tests, assets, and desktop/mobile browser flows.
ci:
    mix format --check-formatted
    mix deps.unlock --check-unused
    mix precommit
    mix assets.build
    npm run test:e2e

assets:
    mix assets.build

# Build production assets and a release without deploying.
release:
    MIX_ENV=prod mix compile --warnings-as-errors
    MIX_ENV=prod mix assets.deploy
    MIX_ENV=prod mix release --overwrite

# Report outdated Hex and npm packages, checking both even if one is outdated.
outdated:
    #!/usr/bin/env sh
    status=0
    mix hex.outdated --all || status=$?
    npm outdated || status=$?
    exit "$status"

# Update lockfiles within their version constraints, then verify.
update:
    mix deps.update --all
    npm update
    just check
    just assets

# Install the Chromium build pinned by Playwright.
browser-setup:
    npm ci
    npx playwright install chromium

# Run desktop/mobile browser journeys against an isolated test database.
browser-check:
    npm run test:e2e

# Open the latest local browser report.
browser-report:
    npm run test:e2e:report
