Review the Faro.GameEngine implementation for mathematical and rules correctness.

Only modify:
- lib/faro/game_engine/**
- test/faro/game_engine/**

Do not modify:
- Ash resources
- Repo
- migrations
- Oban
- LiveView
- routes
- authentication
- Bitcoin modules

Focus especially on Faro odds, settlement correctness, and deck accounting.

Verify and correct if necessary:

1. Standard bets
- banker card is the losing card
- player card is the winning card
- normal win pays 1:1
- normal loss loses full stake

2. Copper bets
- copper reverses the standard interpretation
- banker card wins for copper
- player card loses for copper
- payout amount remains 1:1

3. Doublets
- if banker and player cards have the same rank:
  - bets on that rank lose half their stake
  - this applies whether or not the bet is coppered
  - bets on unrelated ranks are unaffected
- verify expected delta for a 100 sat bet is -50 sats

4. Call-the-turn
- when final three ranks are all distinct:
  - true odds are 5:1
  - payout is 4:1
  - win delta on 100 sats is +400
  - loss delta is -100
  - house edge is 16.67%

- when final three contain exactly one pair (cat-hop):
  - true odds are 2:1
  - payout is 1:1
  - win delta on 100 sats is +100
  - loss delta is -100
  - house edge is 33.33%

- when final three ranks are all the same:
  - no call-the-turn bet should be allowed

5. Soda card and deck accounting
- shuffled deck starts with 52 cards
- first card is burned as the soda card
- 51 cards remain for play
- 24 standard turns consume 48 cards
- final 3 cards are used for call-the-turn

6. Audit correctness
Verify that audit payloads correctly capture:
- server_seed_hash
- server_seed
- client_seed
- nonce
- algorithm_version
- shuffled deck
- revealed cards
- settlements

Verify that audit verification:
- succeeds for valid payloads
- fails when payloads are tampered with

7. Tests
Add or improve:
- deterministic unit tests with fixed card sequences
- property-based tests using StreamData

Add explicit deterministic tests for:
- standard win
- standard loss
- copper win
- copper loss
- doublet half-loss
- call-the-turn distinct win
- call-the-turn distinct loss
- cat-hop win
- cat-hop loss
- all-equal final three rejection
- soda card handling
- total deck accounting

Hard rule:
Faro.GameEngine must remain pure Elixir with:
- no Repo calls
- no Ash dependencies
- no LiveView dependencies
- no process state
- no Oban dependencies
