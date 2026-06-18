# Day-Slot Economy

The structure of a calendar day and the action-point budgets that govern hub and run work. A day is two ordered activity slots, Day then Night; storage work runs on a per-slot AP pool with deterministic research; auction inspection runs on a separate two-tier AP pool; and customer count scales by the chosen Day/Night selling slot. `MetaManager` is the single authority for slot progression, living cost, and the day-end sequence; `SaveManager` holds the persisted slot/AP state it mutates.

## Goal

Give the hub moment-to-moment agency and let a single day mix activities. Instead of a passive day-counter (assign work, click "day pass" until timers tick down) the player spends a scarce resource — slots — across Auction, Storage, and Open Shop, and storage becomes a budgeted set of choices rather than a waiting game. The split is deliberate: gamble at the time-pressured auction, grind deterministically in storage.

## The Slot Day

Each calendar day is two ordered slots, Day then Night. The hub exposes one Activity button; pressing it opens a chooser for the activities valid in the current slot. Cancelling the chooser consumes nothing.

- **Auction** — Day only. Consumes the Day slot, so the player travels, inspects/bids/loads cargo, and returns for the Night slot. One auction per day.
- **Storage** — Available in Day or Night. Begins a fresh per-slot AP pool (see Storage AP) and advances exactly one slot.
- **Open Shop** — Available in Day or Night. Generates customer traffic for the chosen slot and advances exactly one slot.

`MetaManager` owns the slot transitions: a method per activity advances `current_slot` and seeds the relevant state. Every activity advances exactly one step: Day to Night, Night to day-ending. The hub, seeing the day-ending sentinel on re-entry, runs the day-end sequence.

A completed auction returns the player to the Night slot and stashes the run's economics as a _pending run_ on `SaveManager`, persisted so a quit before day-end doesn't drop them. The day-end sequence folds those pending economics, plus customer sales, into the day summary, advances `current_day`, deducts living cost once, and resets slot state for the next day.

## Storage AP

Storage actions spend from a per-**slot** AP pool, not a per-day one. Beginning a Day Storage slot refreshes the pool to the enlarged working-day budget (25 with current constants); beginning a Night Storage slot refreshes it to the base budget (10). Leftover AP is discarded when the slot ends and never carries forward, and the cost of doing more storage is the auction or selling slot given up, not a shared daily ceiling.

Three actions, each applied immediately on the button press (no day-tick delay):

| Action   | AP cost | Effect                                                                     |
| -------- | ------- | -------------------------------------------------------------------------- |
| Repair   | 2       | Raises condition toward the 0.5 cap.                                       |
| Restore  | 2       | Raises condition from 0.5 toward 1.0, scaled by the Restoration attribute. |
| Research | 4       | Deterministic hidden-clue progress (see below).                            |

Every action follows a **guard → apply → charge** shape, and AP is charged only _after_ the effect lands, so a disabled or no-op action never costs AP. Guards: Repair needs AP and condition below its 0.5 cap; Restore needs AP and condition in the [0.5, 1.0) zone; Research needs AP, condition ≥ 0.5, and at least one unrevealed hidden clue. The condition math (caps, zone/rarity factors, the Restoration coefficient) lives in the `ResearchSlot` service helpers.

> The AP cost table is flat and pending a tuning pass; with a full pool per slot, stacked Storage slots may make full authentication too cheap. (Restore currently costs the same 2 AP as Repair in code — the design intent was a higher Restore cost, so this is a likely tuning target.)

### Deterministic Research

Storage research never rolls. Each Research spend adds a fixed progress amount (base 5, boosted by the Investigation attribute) toward the **first** unrevealed hidden clue. When a clue's accumulated progress reaches its DC it reveals — granting REVEAL category mastery — and the next spend moves to the next unrevealed clue. Progress persists across slots and days, so one clue can be worked toward over several sessions, and the action becomes unavailable once every hidden clue is revealed.

Variance belongs where there is a clock — the on-site auction, whose inspection mechanic stays a gamble. A fail-roll in slow storage work would only punish a player who has already paid slots, AP, and living cost. The clue's DC still sets how much total research it costs, and the Investigation attribute still raises progress per spend — just without luck.

## Auction Two-Tier AP

Auction inspection runs on its own pool on `RunStore`, separate from storage AP, with two independent levers:

- **Per-lot cap** — the spendable budget for the _current_ lot (default 10). Within one lot AP is pure consume; once spent it never regenerates mid-lot, and it never exceeds the cap no matter how full the reserve. Raising the cap deepens inspection of any single lot.
- **Reserve** — a finite pool for the whole visit (default 30). Raising it lets the player inspect more lots deeply across one visit.

Refill happens only at the lot boundary. When a lot is set, the reserve pays the **deficit** (`cap − current AP`) and no more: a weak lot left under-inspected preserves reserve for later lots — a built-in "don't over-inspect junk" incentive with no extra rules. If the reserve can't cover the full deficit it tops up as much as it can and goes to 0; once empty, no further refill occurs and later lots run on whatever AP is left.

```
Enter      AP 10 / Reserve 30
Lot1 -8    AP 2  → boundary: deficit 8  → AP 10 / Reserve 22
Lot2 -10   AP 0  → boundary: deficit 10 → AP 10 / Reserve 12
Lot3 -10   AP 0  → boundary: deficit 10 → AP 10 / Reserve 2
Lot4 -10   AP 0  → boundary: deficit 2 (reserve short) → AP 2 / Reserve 0
Lot5       only 2 AP, no further refill
```

Both values are resolved once at run construction through dedicated resolvers on `RunManager`, the single fold point where future modifiers (car, attributes, perks) will enter. They are currently flat. The first lot of a visit opens at the full cap. This pool replaces the old per-lot fixed `action_quota`; a designer may still cap an individual lot below the pool maximum.

## Customer Scaling

Opening shop maps the current Day/Night slot to a customer count, passed to the customer generator:

| Slot  | Customers |
| ----- | --------- |
| Day   | 4–6       |
| Night | 2–3       |

Opening shop during Day yields the larger traffic window and still leaves Night available afterward. Opening shop during Night yields the smaller traffic window and advances to day-ending. The customer-sell mechanics themselves are unchanged - only the count is derived here (see `customer_sell.md`).

## Living Cost

Living cost ($100/day) is deducted once per calendar day during the day-end sequence, regardless of how the day's slots were spent. It is a property of the calendar day, not of slots.

## Persistence

`SlotStore` persists the current slot index, storage AP, the legacy selling-slot field for save compatibility, and the pending-run economics dict. Storage AP is effectively ephemeral - it refreshes at each Storage slot and resets to 0 at day-end. Per-clue research progress persists on each `ItemEntry` and serializes with it. Auction AP (both tiers) is run-scoped: seeded at visit construction, cleared with run state, never persisted across sessions.

## Invariants

- `MetaManager` is the **only** writer of `current_slot`, living cost, and the day-end sequence. The hub never deducts cost or generates customers itself.
- Storage AP is **per-slot**: full at each Storage slot start, discarded at slot end, never carried.
- Storage research is **deterministic** and must never call the on-site roll path (`ItemEntry.attempt_clue`). The two reveal paths stay separate — gamble at auction, grind in storage.
- Auction AP is **capped per lot** and pure-consume within a lot; it refills toward the cap (deficit only, partial when short) **only at lot boundaries**, stopping once the reserve empties.
- Living cost is **once per calendar day**, never per slot.

## Open Questions

- The AP cost table and pool sizes are flat and untuned; with stacked Storage slots, is 10 AP/slot too generous for full authentication, and should Restore cost more than Repair?
- Auction AP modifier levers (car, attributes, perks) have fold points reserved in `RunManager` but no live terms — what raises the cap vs. the reserve?
