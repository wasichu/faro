# Faro — Database Schema

## Overview

The schema is managed by [Ash](https://ash-hq.org) resources backed by AshPostgres. All primary keys are UUID v4. All timestamps are `utc_datetime_usec` (microsecond precision, UTC).

Six application tables hold game state and accounting data. Two infrastructure tables (`oban_jobs`, `oban_peers`) are owned by Oban and not described here.

---

## Entity Relationships

```
game_sessions ──< game_rounds ──< game_turns
     │                 │
     └──< wallets      └──── audit_records (1:1)
               │
               └──< ledger_entries >──── game_rounds (nullable)
```

- A **session** groups one or more rounds. Each session has exactly one wallet.
- A **round** belongs to a session and holds the provably-fair shuffle parameters.
- Each dealt **turn** within a round records both cards and the bets/settlements for that turn as JSON.
- The **wallet** tracks the player's FTC balance via an append-only **ledger**.
- An **audit record** is written once per round when it completes; it contains the full transcript needed to independently verify the shuffle.

---

## Tables

### `game_sessions`

Top-level session record. Created when a player starts a new game; destroyed (with all children) by the cleanup job after 24 h of inactivity.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `status` | `text` | NOT NULL | `'active'` | `'active'` or `'completed'` |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**Referenced by:** `game_rounds.game_session_id` (CASCADE DELETE), `wallets.game_session_id` (CASCADE DELETE)

---

### `game_rounds`

One round of Faro. Holds all provably-fair seed parameters and the full shuffled deck. Status advances from `:dealing` → `:call_the_turn` → `:finished`. The `server_seed` column is `NULL` until the round finishes — it is only revealed after the last card is dealt, as required by the provably-fair protocol.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `game_session_id` | `uuid` | NULL | — | FK → `game_sessions` CASCADE |
| `nonce` | `bigint` | NOT NULL | — | Monotonically increasing per session |
| `client_seed` | `text` | NOT NULL | — | Provided (or accepted) by the player |
| `server_seed_hash` | `text` | NOT NULL | — | SHA-256 commitment published before the round |
| `server_seed` | `bytea` | NULL | — | Revealed only after round completes |
| `algorithm_version` | `text` | NOT NULL | — | e.g. `'v1'` |
| `soda_rank` | `bigint` | NOT NULL | — | Rank (1–13) of the burned first card |
| `soda_suit` | `text` | NOT NULL | — | Suit of the burned first card |
| `status` | `text` | NOT NULL | `'dealing'` | `'dealing'`, `'call_the_turn'`, or `'finished'` |
| `shuffled_deck` | `jsonb[]` | NOT NULL | — | Full 52-card deck as `[{rank, suit}, ...]` |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**References:** `game_sessions.id` (ON DELETE CASCADE)  
**Referenced by:** `game_turns.round_id` (CASCADE DELETE), `audit_records.round_id` (CASCADE DELETE), `ledger_entries.round_id` (SET NULL)

---

### `game_turns`

One dealt turn within a round. Turns are numbered 1–25. Bets and settlements are stored as JSON arrays rather than normalised rows because they are always read together with the turn and their schema is stable.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `round_id` | `uuid` | NOT NULL | — | FK → `game_rounds` CASCADE |
| `index` | `bigint` | NOT NULL | — | Turn number within the round (1–25) |
| `loser_rank` | `bigint` | NOT NULL | — | Rank of the banker (losing) card |
| `loser_suit` | `text` | NOT NULL | — | |
| `winner_rank` | `bigint` | NOT NULL | — | Rank of the player (winning) card |
| `winner_suit` | `text` | NOT NULL | — | |
| `split` | `boolean` | NOT NULL | `false` | `true` when both cards share the same rank (doublet) |
| `bets` | `jsonb[]` | NOT NULL | `[]` | Serialised bet structs placed on this turn |
| `settlements` | `jsonb[]` | NOT NULL | `[]` | Serialised settlement results |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**References:** `game_rounds.id` (ON DELETE CASCADE)

---

### `wallets`

FTC (fake token coin) wallet for a game session. `balance_sats` is a cached sum of all ledger entries — it must never be updated directly; use `record_turn` or `create_with_topup` to keep it in sync with the ledger.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `game_session_id` | `uuid` | NULL | — | FK → `game_sessions` CASCADE |
| `balance_sats` | `bigint` | NOT NULL | `0` | Cached running total |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**References:** `game_sessions.id` (ON DELETE CASCADE)  
**Referenced by:** `ledger_entries.wallet_id` (CASCADE DELETE)

---

### `ledger_entries`

Append-only accounting log. Every balance change on a wallet produces at least one entry. `amount_sats` is signed: positive = credit, negative = debit.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `wallet_id` | `uuid` | NOT NULL | — | FK → `wallets` CASCADE |
| `round_id` | `uuid` | NULL | — | FK → `game_rounds` SET NULL; NULL for non-turn entries |
| `amount_sats` | `bigint` | NOT NULL | — | Signed: `+` credit, `−` debit |
| `entry_type` | `text` | NOT NULL | — | `'topup'`, `'bet_debit'`, or `'payout_credit'` |
| `note` | `text` | NULL | — | Free-text annotation (e.g. "FTC starting balance") |
| `turn_index` | `bigint` | NULL | — | Turn number within the round (NULL for non-turn entries) |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**References:** `wallets.id` (ON DELETE CASCADE), `game_rounds.id` (ON DELETE SET NULL)

---

### `audit_records`

One record per completed round. Contains everything a third party needs to independently verify the shuffle: the seed commitment published before play, the server seed revealed after, the client seed, the nonce, the full shuffled deck, and a turn-by-turn transcript.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `uuid` | NOT NULL | `gen_random_uuid()` | PK |
| `round_id` | `uuid` | NOT NULL | — | FK → `game_rounds` CASCADE; unique |
| `algorithm_version` | `text` | NOT NULL | — | |
| `server_commitment` | `text` | NOT NULL | — | SHA-256 of the server seed |
| `server_seed` | `bytea` | NOT NULL | — | Revealed after round completion |
| `client_seed` | `text` | NOT NULL | — | |
| `nonce` | `bigint` | NOT NULL | — | |
| `verified` | `boolean` | NOT NULL | `false` | Cached result of `Faro.GameEngine.Audit.verify_full/1` |
| `shuffled_deck` | `jsonb[]` | NOT NULL | — | Full 52-card deck as `[{rank, suit}, ...]` |
| `soda` | `jsonb` | NOT NULL | — | Burned first card as `{rank, suit}` |
| `turns` | `jsonb[]` | NOT NULL | `[]` | Turn-by-turn transcript as serialised maps |
| `inserted_at` | `utc_datetime_usec` | NOT NULL | `now()` | |
| `updated_at` | `utc_datetime_usec` | NOT NULL | `now()` | |

**References:** `game_rounds.id` (ON DELETE CASCADE)  
**Unique index:** `audit_records_unique_round_index` on `(round_id)`

---

## Cascade Delete Summary

Deleting a **session** removes everything beneath it:

```
game_sessions
  ├── game_rounds        (CASCADE)
  │     ├── game_turns   (CASCADE)
  │     └── audit_records (CASCADE)
  │         ledger_entries.round_id → SET NULL
  └── wallets            (CASCADE)
        └── ledger_entries (CASCADE)
```

Deleting a **round** independently (abandoned round cleanup):

```
game_rounds
  ├── game_turns         (CASCADE)
  └── audit_records      (CASCADE)
      ledger_entries.round_id → SET NULL
```

---

## JSON Column Conventions

`bets`, `settlements`, and `turns` are stored as arrays of maps rather than normalised tables. They are always read with their parent row and their structure is stable. See `Faro.FaroGame.Serializer` for the encoding/decoding logic.

Card values (`shuffled_deck`, `soda`) use the format `%{"rank" => integer, "suit" => string}` where rank is 1–13 (Ace–King) and suit is one of `"clubs"`, `"diamonds"`, `"hearts"`, `"spades"`.
