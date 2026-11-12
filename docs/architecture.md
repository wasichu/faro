# Faro — Architecture

## Overview

Faro is a historically accurate Faro card-game simulator built with Elixir, Phoenix LiveView, and Ash. It is structured as a clean-architecture application with strict boundaries between the pure game engine, persistence, and the web layer.

## Namespace Map

| Namespace | Role |
|---|---|
| `FaroWeb` | Phoenix LiveView controllers, router, HTML components |
| `Faro.GameEngine` | Pure Elixir game logic — no I/O, no process state |
| `Faro.Accounts` | Placeholder domain for future authentication; play is anonymous |
| `Faro.Wallets` | Placeholder domain; current FTC wallet/ledger resources live in `Faro.FaroGame` |
| `Faro.FaroGame` | Game session persistence and lifecycle coordination |
| `Faro.Bitcoin` | Bitcoin Core regtest adapter (future phase) |
| `Faro.Audit` | Provably-fair transcripts and verification records |

---

## Pure Engine Philosophy

`Faro.GameEngine` contains zero impure code. Every function is a pure transformation of immutable data:

- No `Repo` calls.
- No `Ash` resources.
- No Phoenix/LiveView dependencies.
- No process state (no GenServers, no Agent).
- No randomness — callers supply seeds.

This means the entire game engine is trivially testable, reproducible, and auditable. A shuffled deck plus a seed always yields the same game — forever.

### GameEngine Modules

| Module | Responsibility |
|---|---|
| `Card` | Rank-only card value (suit irrelevant in Faro) |
| `Deck` | 52-card deck construction and sizing |
| `Shuffle` | Deterministic Fisher-Yates shuffle given a seed |
| `Fairness` | Seed commitment, reveal, and verification (SHA-256) |
| `Round` | Immutable round state machine (shuffled deck → sequence of turns) |
| `Turn` | Two-card deal result (loser + winner; split detection) |
| `Bet` | Player wager (rank, amount, copper flag) |
| `CallTheTurnBet` | Call-the-turn wager (predicted loser + winner ranks, amount) |
| `HighCardBet` | High-card wager (amount, copper flag) |
| `Settlement` | Bet resolution against a turn result |
| `Casekeeper` | Tracks seen ranks to inform player strategy |
| `Audit` | Assembles per-round transcript for external verification |

---

## Ledger Philosophy

Token movements are append-only through the application action API. `Wallet.balance_sats`
is a mutable cache of the signed ledger sum. It is updated only with its debit/credit
entries in the same transaction. The LiveView's spendable balance subtracts pending
wagers from this settled balance; pending reservations are not persisted as settled losses.
Retention deliberately removes old anonymous sessions and their ledger history via cascades.

This design guarantees:

- Full historical auditability.
- No silent balance mutation bugs.
- Easy point-in-time balance reconstruction.
- Natural fit for eventual Bitcoin UTXO-style accounting.

---

## Provably Fair Design

Before each round, the server:

1. Generates a random `server_seed`.
2. Commits to it: `commitment = SHA-256(server_seed)` — published to the player.

The player may supply a `client_seed`. Editing it before the first deal preserves
the original server seed and commitment. The shuffle seed is
`HMAC-SHA256(server_seed, client_seed <> <<nonce::big-64>>)`, not a concatenation
of the two seeds. The fixed `faro-shuffle-v1` shuffle then uses that derived seed.
The nonce is an unsigned 64-bit integer; overflow is rejected.

After completion, verification checks the commitment, algorithm version, exact
shuffled deck and soda, all 25 sequential turns, split flags, wagers, and payouts.
The audit page additionally checks the persisted suits. Full verification requires
a separate bets field; reconstructing wagers from payouts could hide omitted
settlements. The original `game_turns.bets` field supplies that independent wager
source for historical rounds on the persisted audit page. Older standalone
transcripts without it cannot pass full verification.

To establish the commitment protocol independently, a player must record the
commitment before submitting their own client seed. Reproducing a completed
shuffle proves consistency with that commitment; it does not prove the server
never abandoned a round or authenticate which wagers the player originally submitted.
A browser refresh starts a new anonymous session; unfinished rounds cannot be
resumed because their private server seeds are held only in the LiveView process.

---

## FTC-Only v1

In version 1, all wagering uses Fake Token Currency (FTC) — integer token units with no real-world value. There is no real money handling, no payment processing, and no regulatory exposure.

The `FaroGame.start_game` action provisions a session, a wallet, its 1,000,000-token grant, and the first round atomically. `Faro.Wallets` is a placeholder; no `WalletAdapter` behaviour or registration flow is implemented.

---

## Future: Bitcoin Regtest Integration

In a future phase, a future wallet adapter backed by `Faro.Bitcoin` will allow wagering with Bitcoin Core running in regtest mode. Regtest provides full Bitcoin transaction semantics — including real mempool, block confirmation, and fee mechanics — without touching mainnet funds.

The game engine, settlement logic, and audit trail are identical in both modes. A wallet adapter boundary would need to be implemented before that integration.

Key considerations for Bitcoin mode:

- Deposits and withdrawals are Bitcoin transactions confirmed on regtest.
- Bet amounts are denominated in satoshis.
- Settlement produces Bitcoin transactions, not ledger entries.
- `Faro.Bitcoin` wraps Bitcoin Core JSON-RPC via `Req`.

---

## Gameplay transactions

`FaroGame.deal_game_turn` is the authoritative action. It locks the persisted
round and wallet, checks session ownership and the expected turn number, replays
the stored deck/bets, validates funding and phase, and computes settlements.
The turn, ledger entries, settled balance, round status, final seed reveal/audit,
and session activity timestamp commit together. Dedicated activity/advance actions
set `updated_at` explicitly, including when the status itself is unchanged. Failure rolls everything back;
the LiveView retains its previous state and pending reservations.

A unique database index enforces `(round_id, index)` for turns; another enforces
one wallet per non-null session. Ledger entries, dealt turns, and completed audit
records expose no general update/destroy actions. Cleanup uses explicit parent
retention actions and database cascades.

The final-card pool is sorted independently of the hidden deal order. Engine
settlement uses integer amounts: a doublet takes `div(amount, 2)`, rounding the
house's half down for an odd stake. The v1 shuffle's negligible modulo bias is
preserved for compatibility; its output is covered by an independent golden vector.

## Dependency Rules

```
FaroWeb → FaroGame, Audit.Verification
FaroGame → GameEngine, Audit records
Audit.Verification → GameEngine, FaroGame.Serializer
GameEngine → Elixir/OTP only (deterministic; callers supply entropy)
```

The Accounts, Wallets, and Bitcoin domains are placeholders, not completed adapters.
