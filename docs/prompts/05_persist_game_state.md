Connect the existing LiveView gameplay prototype to Ash persistence.

Goals:
- persist FTC gameplay
- allow page refresh/reload recovery
- support replaying previous rounds
- keep all existing gameplay behavior working

Requirements:

1. Game session lifecycle
- create a GameSession when a new FTC game starts
- persist new Rounds
- persist Turns as they resolve
- persist Bets and Settlements

2. Fairness persistence
Persist:
- server_seed_hash
- revealed server_seed at round end
- client_seed
- nonce
- algorithm_version
- shuffled deck/audit payload
- soda card

3. Turn persistence
Persist:
- banker card
- player card
- doublets
- call-the-turn outcomes
- settlements
- revealed card history

4. Replay support
- allow reconstructing a persisted round from stored data
- preserve deterministic audit verification

5. LiveView integration
- existing UI behavior should continue working
- reconnect LiveView to persisted state instead of only assigns
- keep UI responsive and simple

6. Hard constraints
- do not add BTC yet
- do not add wallet ledger yet
- do not add Oban jobs yet
- do not move game logic into Ash resources
- do not make GameEngine depend on persistence
