Redesign the Call the Turn UI and phase behavior.

Desired interaction:
- When three cards remain, show a distinct Call the Turn mode.
- Show three prediction slots labeled 1, 2, and 3.
- Show the three remaining cards as selectable cards.
- User clicks a card, then clicks a slot to place it there.
- A placed card should disappear from the available-card area.
- Clicking a placed card removes it from the slot and returns it to available cards.
- User selects/enters the Call the Turn bet amount separately.
- Submit button should be disabled until all three slots are filled and bet amount is valid.
- After submit/deal, reveal actual order and show win/loss result.
- Clearly display:
  - predicted order
  - actual order
  - payout/result
  - whether the prediction matched
- In the Turn Settlement display and recent turn history, Call the Turn should display all 3 final cards instead of the normal 2-card turn display.
- The part at the top of the game UI that lists the number of cards remaining should say 0 cards remain after the CTT round.

Phase behavior:
- When the round enters Call the Turn mode:
  - disable all standard betting controls
  - disable all copper betting controls
  - prevent adding/removing normal pending bets
  - visually indicate this is the special final betting phase
  - only allow interaction with the Call the Turn prediction UI and its bet amount
- Ensure both the UI and LiveView event handlers enforce this.
- If normal pending bets somehow exist when entering Call the Turn mode, clear them safely.

Use LiveView click events only for now. Do not implement HTML drag-and-drop yet.

Keep all state in LiveView assigns.
Do not add persistence, Ash, Repo, Oban, BTC, or routing changes unless absolutely necessary.
