Implement the first real version of the pure Faro game engine.

Focus only on pure deterministic logic.
No Ash resources.
No database persistence.
No LiveView.

Implement:

- Faro.GameEngine.Card
- Faro.GameEngine.Deck
- Faro.GameEngine.Fairness
- Faro.GameEngine.Shuffle
- Faro.GameEngine.Round
- Faro.GameEngine.Turn
- Faro.GameEngine.Bet
- Faro.GameEngine.Settlement
- Faro.GameEngine.Casekeeper
- Faro.GameEngine.Audit

Requirements:

1. Card and deck system
- immutable card structs
- suit/rank representation
- standard 52-card deck generation
- deterministic serialization helpers

2. Provably fair shuffle
Implement:
- generate_server_seed/0
- commit_server_seed/1 using SHA-256
- deterministic randomness derivation from:
  - server_seed
  - client_seed
  - nonce
- deterministic Fisher-Yates shuffle
- algorithm_version field:
  "faro-shuffle-v1"

3. Faro turn logic
- each Turn contains:
  - betting phase
  - revealed banker card
  - revealed player card
  - settlements

4. Settlement rules
Implement:
- standard bets
- copper bets
- doublet half-loss rule
- settlement delta calculations in integer sats

5. Call-the-turn support
- final three cards
- cat-hop handling
- payout calculations
- invalid all-equal final-three handling

6. Casekeeper
Derive remaining/dealt counts from revealed cards.

7. Audit verification
Generate deterministic audit payloads that can fully verify:
- server seed hash
- shuffled deck
- revealed cards
- settlement correctness

8. Tests
Add:
- ExUnit tests
- StreamData property tests

Test:
- deck uniqueness
- shuffle determinism
- nonce variation
- audit tamper detection
- settlement invariants
- copper logic
- doublet logic
- call-the-turn payout correctness
