Continue Step 3 by turning the UI shell into a playable FTC-only prototype.

This must use only:
- LiveView state
- Faro.GameEngine pure functions

Do not add:
- Ash resources
- database persistence
- Repo calls
- Oban
- BTC
- authentication
- ledger/wallet persistence

Goal:
A user should be able to play through a faro round in the browser using fake FTC balance, with all state held in LiveView assigns.

Requirements:
1. On mount, initialize:
   - fake FTC balance
   - new shuffled round from Faro.GameEngine
   - casekeeper
   - empty pending bets
   - empty revealed cards/settlements

2. Betting:
   - allow placing standard bets by rank
   - allow placing copper bets by rank
   - prevent bets above current fake balance
   - show pending bets before dealing

3. Turn flow:
   - close betting for current turn
   - reveal banker/losing card
   - reveal player/winning card
   - settle pending bets using Faro.GameEngine
   - update fake balance
   - update casekeeper
   - clear resolved bets
   - advance to next turn

4. Doublets:
   - display doublet result clearly
   - apply half-loss correctly

5. Call-the-turn:
   - when final three cards remain, switch UI into call-the-turn mode
   - allow selecting predicted order
   - settle according to GameEngine
   - end the round

6. Round ending:
   - show final result summary
   - reveal server seed
   - show audit payload or placeholder audit panel
   - allow starting a new FTC round

7. UI:
   - keep saloon/table aesthetic from Part 1
   - show betting board
   - show balance
   - show banker/player cards
   - show casekeeper
   - show recent turn result
   - show remaining card count

Hard constraints:
- No persistence.
- No database writes.
- No Ash.
- No Repo.
- No Oban.
- No BTC.
- Faro.GameEngine must remain pure and unchanged unless small fixes are required.

---

Change betting board click behavior.

Current behavior:
- repeatedly clicking the same rank adds additional pending bets.

Desired behavior:
- clicking a rank with no pending bet adds a pending bet using the currently selected amount and bet type
- clicking a rank that already has a pending bet removes that pending bet
- do not stack multiple pending bets on the same rank
- to change bet amount or copper/standard type, user must remove the existing bet and place it again
- update displayed pending bet totals and fake balance accordingly
- keep this behavior only in the LiveView/UI layer unless GameEngine already has a suitable helper

Do not modify persistence, Ash, Oban, Bitcoin, or routing.
