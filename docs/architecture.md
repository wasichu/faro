# Faro — Architecture

## Overview

Faro is a historically accurate Faro card-game simulator built with Elixir, Phoenix LiveView, and Ash. It is structured as a clean-architecture application with strict boundaries between the pure game engine, persistence, and the web layer.

## Namespace Map

| Namespace | Role |
|---|---|
| `FaroWeb` | Phoenix LiveView controllers, router, HTML components |
| `Faro.GameEngine` | Pure Elixir game logic — no I/O, no process state |
| `Faro.Accounts` | User identity, registration, authentication (AshAuthentication) |
| `Faro.Wallets` | Append-only token ledger (FTC v1, Bitcoin regtest v2) |
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
| `Settlement` | Bet resolution against a turn result |
| `Casekeeper` | Tracks seen ranks to inform player strategy |
| `Audit` | Assembles per-round transcript for external verification |

---

## Ledger Philosophy

All token movements are append-only. There is no mutable balance field on any account. A player's balance at any point in time is the sum of all ledger entries for their account up to that moment.

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

The player provides a `client_nonce` before cards are dealt.

The combined seed `server_seed <> client_nonce` is fed to `Shuffle`. After the round, the server reveals `server_seed`. Any observer can:

1. Verify `SHA-256(server_seed) == commitment`.
2. Reproduce the shuffle from the combined seed.
3. Step through every turn and confirm the audit transcript.

No trust in the server is required beyond the pre-round commitment.

---

## FTC-Only v1

In version 1, all wagering uses Fake Token Currency (FTC) — integer token units with no real-world value. There is no real money handling, no payment processing, and no regulatory exposure.

The `Faro.Wallets` domain uses an internal `WalletAdapter` behaviour. The FTC adapter is the only implementation in v1. Players are provisioned with a starting FTC balance on registration.

---

## Future: Bitcoin Regtest Integration

In a future phase, a second `WalletAdapter` implementation backed by `Faro.Bitcoin` will allow wagering with Bitcoin Core running in regtest mode. Regtest provides full Bitcoin transaction semantics — including real mempool, block confirmation, and fee mechanics — without touching mainnet funds.

The game engine, settlement logic, and audit trail are identical in both modes. Only the wallet adapter changes. This is the core benefit of the adapter boundary introduced in v1.

Key considerations for Bitcoin mode:

- Deposits and withdrawals are Bitcoin transactions confirmed on regtest.
- Bet amounts are denominated in satoshis.
- Settlement produces Bitcoin transactions, not ledger entries.
- `Faro.Bitcoin` wraps Bitcoin Core JSON-RPC via `Req`.

---

## Dependency Rules

```
FaroWeb → FaroGame, Accounts, Wallets, Audit
FaroGame → GameEngine, Wallets, Audit
Wallets → (WalletAdapter behaviour) → FTC adapter | Bitcoin adapter
Bitcoin → (external: Bitcoin Core RPC)
GameEngine → (nothing — pure functions only)
Audit → (nothing — pure data assembly only)
```

Arrows represent "may call". No reverse dependencies are permitted.
