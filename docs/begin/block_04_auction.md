# Block 04 — Auction Bid

The player watches a live bidding sequence and decides when — or whether — to drop out.

---

## Receives

- `GameManager.current_lot` — all 4 items

---

## Produces

- `GameManager.lot_result`
  - `paid_price` (int) — `current_display_price` at the moment of resolution; 0 if passed
  - `won_items` (Array[ItemData]) — all 4 items if won; empty array if passed

---

## Core Concept

The auction is a simulation, not a negotiation.

On entry, a hidden `rolled_price` is calculated. This is the true closing price. The bidding sequence runs upward toward it automatically. The player cannot change this outcome — they can only decide whether to stay in or walk away before it resolves.

The Bid button, NPC bid popups, and circle progression are all display-layer events. They make the sequence feel contested. None of them affect `rolled_price` or the termination condition.

---

## Logic Layer

### On Entry
- Calculate `rolled_price`:
  ```
  rolled_price = sum of all item true_values * randf_range(0.6, 1.2)
  ```
  Round to nearest int. Store privately. Never expose to UI directly.
- Set `current_display_price` to a starting value equal to the value shown in Block 03 (List Review).
  Round to nearest int.

### NPC Tick System
- A timer fires every `npc_tick_interval` seconds, re-rolled each cycle: `randf_range(0.5, 5.0)`
- On each tick:
  - Increment `current_display_price` by a random step: `randf_range(0.04, 0.09) * rolled_price`, minimum step = 100, rounded to int
  - Trigger NPC bid popup (see Display Layer)
  - Reset circle progression to 0 (see Display Layer)
  - Check termination condition

### Termination Condition
- Checked once after each NPC tick increments `current_display_price`
- If `current_display_price >= rolled_price`:
  - NPC tick timer stops — no further NPC bids will fire
  - Circle progression continues running from its current position
  - State is now **reach**: waiting for circle to complete
- Otherwise: continue; next NPC tick fires at its scheduled interval

### Resolution (triggered when circle progression completes in **reach** state)
- If the last bid was from the player:
  - Auction resolves as **won**
  - `paid_price` = `current_display_price`
  - `won_items` = all items in `current_lot`
  - Advance to Block 05 (Cargo Loading)
- If the last bid was from an NPC:
  - Auction resolves as **lost**
  - `paid_price` = 0, `won_items` = empty array
  - Advance to Block 06 (Home Appraisal) with nothing to show

### Player Actions
- **Bid**: display-layer only; see Display Layer for effects. Does not affect `rolled_price`, step size, or termination condition.
  - Disabled if the last bid was from the player — re-enabled after the next NPC tick
- **Pass**:
  - Stops the NPC tick timer immediately
  - Sets `paid_price` = 0, `won_items` = empty array
  - Advances to Block 06 (Home Appraisal) with nothing to show

---

## Display Layer

All of the following are visual and audio responses only. None of them affect game logic.

### Circle Progression
- Fills continuously from 0 to 100% over `closing_interval` seconds, re-rolled each cycle: `randf_range(5.0, 8.0)`
- Resets to 0 whenever any bid occurs — NPC tick or player Bid
- Purely atmospheric — circle completion has no effect on game logic
- Conveys time pressure only; the auction does not close when it fills

### NPC Bid Popup
- On each NPC tick, show a brief label near the price (e.g. "Bidder 3 — $1,200")
- NPC name randomised from a short fixed list
- Tween in quickly, hold 0.8s, tween out
- Displayed amount equals `current_display_price` after the step is applied

### Player Presses Bid
- `current_display_price` gets a small cosmetic bump: `+ 100` (fixed, same as minimum step)
  - This bump is part of the normal upward crawl — it does not trigger a termination check
- Circle progression resets to 0 and begins filling again
- Next NPC tick interval shortens for one cycle only: `npc_tick_interval * 0.7`
  - Makes the NPC feel reactive
- Play a short confirm sound

### Price Display
- Central price label tweens to the new value on each change (player Bid or NPC tick)
- Tween duration: 0.3s
- Large and prominent — this number is the focal point of the screen

---

## UI Layout

- **Centre**: `current_display_price`, large
- **Around the price**: circle progression
- **Below price**: lot summary — item names only, no values
- **Bottom**: two buttons — **Bid** and **Pass**
- NPC bid popups appear near the price, not in a separate panel

No negotiation. No counter-offer. No multiple rounds.

---

## Notes

- The player's only real decision is **when to Pass** — everything else is atmosphere
- The illusion works as long as Bid feels responsive; prioritise the visual feedback on that button
- `rolled_price` must never be logged or exposed in any debug UI visible during playtesting
- "Pass" must still route to Block 06, not terminate the run
- Use four spaces instead of tabs to indent