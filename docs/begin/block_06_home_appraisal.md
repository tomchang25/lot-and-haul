# Block 06 — Home Appraisal

The player returns home and learns the true value of everything they brought back.

---

## Receives

- `GameManager.cargo_items` — items that were loaded
- `GameManager.lot_result.paid_price` — what the player paid at auction

---

## Produces

Nothing. End of the run.

---

## Requirements

### Reveal Sequence
- Display cargo items one at a time in a list
- Each item starts hidden (name visible, value shown as "???")
- Reveal items sequentially — player clicks or presses a button to reveal the next one
- On reveal, show the item's true value

### Settlement
- After all items are revealed, show a summary:
    - Total sell value (sum of all cargo item true values)
    - Amount paid at auction
    - Net result (profit or loss), clearly labelled
- If the player passed at auction, show "You walked away empty-handed" and net = 0

### Restart
- A single "Run Again" button resets `GameManager` state and returns to Block 02 (Inspection)
- No persistent state is saved between runs in this slice

---

## Note

- True values are revealed here for the first time — this is the payoff moment
- Do not apply damage, fakes, or surprise events to items in this slice
- "Run Again" must fully reset inspection results, lot result, and cargo items
