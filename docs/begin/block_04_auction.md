# Block 04 — Auction Bid

The player decides whether to buy the entire lot at the NPC's asking price.

---

## Receives

- `GameManager.current_lot` — all 4 items

---

## Produces

- `GameManager.lot_result`
    - `paid_price` (int) — 0 if passed, NPC bid price if accepted
    - `won_items` (Array[ItemData]) — empty if passed, all 4 items if accepted

---

## Requirements

### Bid Price
- Fixed formula: sum of all item true values x 0.75
- Calculated once on entry, not randomised
- Displayed clearly on screen

### Player Decision
- Two buttons: "Accept" and "Pass"
- Accept:
    - Sets `paid_price` to the bid price
    - Sets `won_items` to all items in `current_lot`
    - Advances to Block 05 (Cargo Loading)
- Pass:
    - Sets `paid_price` to 0
    - Sets `won_items` to empty array
    - Skips directly to Block 06 (Home Appraisal) with nothing to show

### UI
- Show the bid price prominently
- Show a brief summary of what is in the lot (item names only)
- No negotiation, no counter-offer, no multiple rounds

---

## Note

- This is the single highest-tension moment in the loop — the UI should give it space
- Do not add randomness to the NPC price in this slice
- "Pass" must still route to Block 06, not terminate the run
