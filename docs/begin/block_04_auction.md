# Block 04 — Auction Bid

The player watches a live bidding sequence and decides when — or whether — to drop out.

---

## Receives

- `GameManager.current_lot` — all 4 items
- `GameManager.inspection_results` — inspection levels per item (used for lot summary display)

---

## Produces

- `GameManager.lot_result`
  - `paid_price` (int) — `current_display_price` at the moment of resolution; 0 if passed or lost
  - `won_items` (Array[ItemData]) — all 4 items if won; empty array if passed or lost

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
  rolled_price = roundi(sum of all item true_values * randf_range(0.6, 1.2))
  ```
  Store privately. Never expose to UI directly.
- Set `current_display_price` to the opening bid shown in Block 03 (sum of true values × 0.25), rounded to nearest int.
- Set `_last_bidder` to `"npc"`.

### NPC Tick System
- A one-shot Timer fires at an interval determined by progress toward `rolled_price`:
  - If `current_display_price / rolled_price >= 0.75`: interval = `randf_range(1.0, 3.0)`
  - If `current_display_price / rolled_price < 0.75`: interval = `randf_range(0.5, 1.0)`
  - Additionally, 25% of the time the interval is halved regardless of progress
  - If `_shorten_next_npc_tick` is true, the interval is halved for one cycle only (set by player Bid)
- On each tick:
  - Calculate step: base = `maxi(roundi(randf_range(0.04, 0.09) * rolled_price), 100)`; if progress < 0.75, multiply base by 1.5
  - Increment `current_display_price` by step
  - Set `_last_bidder = "npc"`
  - Re-enable Bid and Pass buttons
  - Trigger NPC bid popup, reset circle, tween price label
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
  - Call `GameManager.go_to_cargo()`
- If the last bid was from an NPC:
  - Auction resolves as **lost**
  - `paid_price` = 0, `won_items` = empty array
  - Call `GameManager.go_to_appraisal()`

### Player Actions
- **Bid**: display-layer only; see Display Layer for effects. Does not affect `rolled_price`, step size, or termination condition.
  - Disabled if the last bid was from the player — Pass button is also disabled during this window
  - Both re-enabled after the next NPC tick
- **Pass**:
  - Stops the NPC tick timer and kills the circle tween immediately
  - Sets `paid_price` = 0, `won_items` = empty array
  - Calls `GameManager.go_to_appraisal()`

---

## Display Layer

All of the following are visual and audio responses only. None of them affect game logic.

### Circle Progression
- Fills continuously from 0 to 100% over `closing_interval` seconds, re-rolled each cycle: `randf_range(5.0, 8.0)`
- Remaining duration is proportional to `1.0 - current_fill` so an interrupted fill doesn't restart from full duration
- Resets to 0 whenever any bid occurs — NPC tick or player Bid
- In normal state: loops atmospherically on completion — no game effect
- In **reach** state: completion triggers `_resolve()`

### NPC Bid Popup
- On each NPC tick, a new Label is appended to `_npc_history_list` (a VBoxContainer near the price)
- Format: `"Bidder X — $1,200"`; NPC name picked randomly from a fixed list with no-repeat guard against the previous pick
- Fade in over 0.15s → hold 3.0s → fade out over 0.5s → `queue_free()`
- If the list exceeds 5 children, the oldest is freed immediately

### Player Presses Bid
- `current_display_price` gets a cosmetic bump: `+ 100` (fixed; does not trigger termination check)
- A `"YOU — $X"` label is added to `_npc_history_list` in gold colour, auto-removed after 3s
- Circle progression resets to 0 and begins filling again
- `_shorten_next_npc_tick = true` — next NPC tick interval halved for one cycle only (makes the NPC feel reactive)
- TODO: play confirm sound via AudioManager

### Price Display
- Central price label tweens from its current in-flight value to the new value on each change (player Bid or NPC tick)
- Tween duration: 0.3s
- Large and prominent — this number is the focal point of the screen

---

## UI Layout

- **Centre**: `current_display_price`, large (font size 42)
- **Around the price**: `_CircleProgress` inner class draws the arc directly via `_draw()`
- **Right of price circle**: `_npc_history_list` — stacked bid labels (NPC and player)
- **Below price**: lot summary — item name + estimated price range per item, total estimate at bottom
- **Bottom**: two buttons — **Pass** and **Bid** (Pass on the left)
- UI is fully code-built in `_build_ui()` — no companion `.tscn` file

No negotiation. No counter-offer. No multiple rounds.

---

## Notes

- The player's only real decision is **when to Pass** — everything else is atmosphere
- The illusion works as long as Bid feels responsive; prioritise the visual feedback on that button
- `rolled_price` must never be logged or exposed in any debug UI visible during playtesting
- "Pass" must still route to Block 06, not terminate the run
- Use four spaces instead of tabs to indent

---

## MVP Todolist

*(No outstanding MVP items — block is implemented)*

## Itch Demo Todolist

- [ ] Audio: play confirm sound on player Bid via AudioManager (stub already in code)
- [ ] Block 04b — Cleanup phase: after winning, before Cargo Loading, player receives 8 additional stamina to re-inspect won items and decide what to drop
- [ ] Garage auction variant: player selects individual items from a list before entering bidding, one-on-one format
- [ ] NPC aggression factor: some NPCs bid more aggressively (shorter tick interval, larger steps) — data-driven, no logic change needed

## Post Demo Todolist

- [ ] Auction house variant: per-item sequential bidding, harder pacing to control
- [ ] Intel system: pre-run info (tip-offs, seller data) that narrows `rolled_price` range before the auction starts