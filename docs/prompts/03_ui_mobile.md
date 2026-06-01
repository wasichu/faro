Fix the mobile gameplay layout for the Faro LiveView UI.

Focus only on responsive/mobile UI and small LiveView interaction fixes. Do not change game rules, persistence, Ash resources, Oban, Bitcoin code, routing, or core GameEngine behavior unless absolutely necessary.

Mobile requirements:

1. Mobile navigation

* On smaller viewports, the normal header menu currently disappears.
* Add a mobile hamburger menu.
* The hamburger should reveal the same primary navigation links as the desktop header.
* Keep the desktop header unchanged on larger viewports.

2. Mobile betting board layout

* On smaller viewports, the cards on the table get scrunched together.
* Add a mobile-specific betting board layout.
* Prefer a compact layout like 3 rows of 4 ranks, with the 7 still visually offset/separate if practical.
* Keep the desktop betting board layout unchanged.

3. Stable betting controls layout

* In the bet section, result messages and repeat-bet states currently cause the Deal Turn and Repeat Bets buttons to move around.
* Make this section layout stable across states.
* Put the bet amount line and Copper toggle on one consistent row/area.
* Put Repeat Bets and Deal Turn on their own consistent row below the bet controls.
* Always report the latest turn result in the same fixed location in this section so controls do not jump around.

4. Recent Turns stacking

* On mobile, Recent Turns can get pushed sideways beside other content.
* Make Recent Turns stack below the current Turn section on small viewports.
* Keep desktop layout unchanged if it already works well.

5. Call the Turn card display

* In mobile view, the Call the Turn result display currently lets the third final card run off the side of the screen.
* Adjust the Turn display for Call the Turn so all three final cards fit.
* Acceptable fixes:

  * show final cards closer together,
  * reduce their size on mobile,
  * wrap them cleanly,
  * or stack them vertically inside the result area.
* Make sure the result box remains readable.

6. Skip Final Bet behavior

* During Call the Turn, if at least one card has been placed into the predicted order, disable the Skip Final Bet button.
* Skip Final Bet should only be clickable when no prediction cards have been placed.
* If all prediction slots are empty, Skip Final Bet should be enabled.
* Keep the existing requirement that normal bets are disabled during Call the Turn.

General requirements:

* Preserve existing visual style.
* Prefer simple responsive CSS/Tailwind classes over complex JavaScript.
* Keep LiveView state transitions clean.
* Test manually at mobile widths around 375px and 430px.
* Ensure desktop view is not broken by the mobile changes.

