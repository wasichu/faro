Step 7: Build audit, verification, fairness, rules, and odds pages.

Goals:
- make the provably fair system understandable
- allow manual shuffle verification
- allow full persisted round verification
- link completed rounds to their audit pages
- add client-seed controls before or during this work

Pages:
- /audit/shuffle
- /audit/rounds/:id
- /fairness
- /rules
- /odds

Client Seed Requirements:
- generate a default client seed in the browser using secure randomness
- display the current client seed in the gameplay UI
- add a “Regenerate” button
- add an optional “Advanced” toggle/input for manual client-seed entry
- lock the client seed once a round begins
- display server_seed_hash before the round starts
- ensure each round shuffle uses:
  - server_seed
  - client_seed
  - nonce
  - algorithm_version

Verifier Mode 1: Manual Shuffle Verifier
- route: /audit/shuffle
- user manually enters:
  - server_seed
  - server_seed_hash
  - client_seed
  - nonce
  - algorithm_version
- verifier recomputes and displays:
  - server seed hash match
  - shuffled deck
  - soda card
  - standard turn card sequence
  - final three cards
- show clear pass/fail results

Verifier Mode 2: Persisted Round Audit
- route: /audit/rounds/:id
- link to this page from the end-of-round/game summary
- load persisted round data
- display:
  - server_seed_hash
  - revealed server_seed
  - client_seed
  - nonce
  - algorithm_version
  - shuffled deck
  - soda card
  - full turn history
  - all bets
  - all settlements
  - call-the-turn prediction/result if present
- verify:
  - server seed hash
  - shuffle correctness
  - dealt card order
  - soda card
  - bet settlement correctness
  - call-the-turn correctness
- show clear pass/fail status for each verification step

Gameplay UI Requirement:
- after a round ends, show a clear “Verify this round” or “Audit this round” link
- if persistence is available, link to /audit/rounds/:id
- if persistence is not available yet, show a temporary audit payload panel or disabled placeholder

Fairness Page:
- explain server seed, client seed, nonce, and algorithm version
- explain why the server seed hash is shown before play
- explain why the server seed is revealed after the round
- explain how users can independently verify the shuffle

Rules Page:
- explain standard faro play
- explain banker/losing card and player/winning card
- explain copper bets
- explain doublets
- explain soda card
- explain call-the-turn and skipping the final bet

Odds Page:
- list standard bet behavior
- list copper bet behavior
- explain doublet half-loss
- explain call-the-turn odds:
  - distinct final three: true odds 5:1, payout 4:1
  - cat-hop: true odds 2:1, payout 1:1
  - all same: no final bet
- phrase historical fairness claims carefully

Do not add:
- BTC
- deposits
- withdrawals
- PSBT flows
- new Oban workflows
