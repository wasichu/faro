# Faro

A historically accurate Faro card-game simulator built with Phoenix LiveView and Ash Framework.

## Prerequisites

- Elixir / Erlang
- Docker (for the Postgres database)

## Development setup

```bash
# Install dependencies and set up the database
mix setup

# Start Postgres + the Phoenix server in one step
mix dev
```

`mix dev` runs `docker compose up -d` (starts the Postgres container defined in
`docker-compose.yml`) and then launches the Phoenix server. Visit
[localhost:4000](http://localhost:4000).

You can also run them separately:

```bash
docker compose up -d   # start Postgres only
mix phx.server         # start Phoenix only
```

Or interactively:

```bash
mix docker.up
iex -S mix phx.server
```

## Database

The `docker-compose.yml` in the project root defines a single Postgres 18
service (`faro_postgres`) on the default port 5432. Credentials match
`config/dev.exs`:

| Setting  | Value      |
|----------|------------|
| User     | `postgres` |
| Password | `postgres` |
| Database | `faro_dev` |

To reset the database:

```bash
mix ecto.reset
```

## Running tests

```bash
mix test
```

Tests use a separate `faro_test` database and run migrations automatically.

## Pre-commit checks

```bash
mix precommit
```

Compiles with warnings-as-errors, removes unused deps, formats code, and runs
the full test suite.
