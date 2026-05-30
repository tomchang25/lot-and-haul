# Day-Slot Economy

The structure of a calendar day and the action-point budgets that govern hub and run work. A day is three slots the player allocates to activities; storage work runs on a per-slot AP pool with deterministic research; auction inspection runs on a separate two-tier AP pool; and the nightly customer count scales with how much of the day was committed to selling. `MetaManager` is the single authority for slot progression, living cost, and the day-end sequence; `SaveManager` holds the persisted slot/AP state it mutates.

## Goal

Give the hub moment-to-moment agency and let a single day mix activities. Instead of a passive day-counter (assign work, click "day pass" until timers tick down) the player spends a scarce resource — slots — across Auction, Storage, and Open Shop, and storage becomes a budgeted set of choices rather than a waiting game. The split is deliberate: gamble at the time-pressured auction, grind deterministically in storage.

## The Slot Day

Each calendar day is three ordered slots — Morning, Afternoon, Evening — tracked by `SaveManager.current_slot` (1–3). The three activities a slot can hold:

- **Auction** — Morning only. Consumes the morning _and_ afternoon slots: choosing it advances `current_slot` to 3, so the player travels, inspects/bids/loads cargo, and returns for the Evening slot. One auction per day.
- **Storage** — Available in any open slot. Begins a fresh per-slot AP pool (see Storage AP). Multiple Storage slots in a day stack into proportionally more work because each grants its own full pool.
- **Open Shop** — Triggers the nightly customer sell and ends the day. The number of slots still uncommitted when Open Shop is chosen becomes the _selling-slot commitment_ that scales customer traffic.

`MetaManager` owns the slot transitions: a method per activity advances `current_slot` and seeds the relevant state. Open Shop pushes `current_slot` past 3 as a sentinel; the hub, seeing `current_slot > 3` on re-entry, runs the day-end sequence. The day also ends naturally once all three slots are spent.

A completed auction returns the player to the Evening slot (`current_slot = 3`) and stashes the run's economics as a _pending run_ on `SaveManager`, persisted so a quit before day-end doesn't drop them. The day-end sequence folds those pending economics, plus the night's customer sales, into the day summary, advances `current_day`, deducts living cost once, and resets slot state for the next day.

## Storage AP

Storage actions spend from a per-**slot** AP pool, not a per-day one. Beginning a Storage slot refreshes the pool to `Economy.STORAGE_AP_MAX` (10); leftover AP is discarded when the slot ends and never carries forward. A two-Storage-slot day therefore grants 10 + 10 = 20 AP of total work, and the cost of doing more is the auction or selling slot given up — not a shared daily ceiling.

Three actions, each applied immediately on the button press (no day-tick delay):

| Action   | AP cost | Effect                                                                     |
| -------- | ------- | -------------------------------------------------------------------------- |
| Repair   | 2       | Raises condition toward the 0.5 cap.                                       |
| Restore  | 2       | Raises condition from 0.5 toward 1.0, scaled by the Restoration attribute. |
| Research | 4       | Deterministic hidden-clue progress (see below).                            |

Every action follows a **guard → apply → charge** shape, and AP is charged only _after_ the effect lands, so a disabled or no-op action never costs AP. Guards: Repair needs AP and condition below its 0.5 cap; Restore needs AP and condition in `[0.5, 1.0)`; Research needs AP, condition ≥ 0.5, and at least one unrevealed hidden clue. The condition math (caps, zone/rarity factors, the Restoration coefficient) lives in the static `ResearchSlot` helpers — that resource kept its math when its day-ticker lifecycle was retired.

> The AP cost table is flat and pending a tuning pass; with a full pool per slot, stacked Storage slots may make full authentication too cheap. (Restore currently costs the same 2 AP as Repair in code — the design intent was a higher Restore cost, so this is a likely tuning target.)

### Deterministic Research

Storage research never rolls. Each Research spend adds `5 + Investigation attribute` progress to the **first** unrevealed hidden clue, accumulated per clue in `ItemEntry.research_progress` (clue_id → int). When a clue's progress reaches its DC it reveals — appended to `revealed_clue_ids`, granting REVEAL category mastery — and the next spend moves to the next unrevealed clue. Progress persists across slots and days, so one clue can be worked toward over several sessions, and the action becomes unavailable once every hidden clue is revealed.

Variance belongs where there is a clock — the on-site auction, whose inspection mechanic stays a gamble. A fail-roll in slow storage work would only punish a player who has already paid slots, AP, and living cost. The clue's DC still sets how much total research it costs, and the Investigation attribute still raises progress per spend — just without luck.

## Auction Two-Tier AP

Auction inspection runs on its own pool on `RunRecord`, separate from storage AP, with two independent levers:

- **Per-lot cap** (`inspection_ap_cap`, default `Economy.INSPECTION_AP_CAP` = 10) — the spendable budget for the _current_ lot. Within one lot AP is pure consume; once spent it never regenerates mid-lot, and it never exceeds the cap no matter how full the reserve. Raising the cap deepens inspection of any single lot.
- **Reserve** (`refill_metric`, default `Economy.INSPECTION_REFILL_METRIC_DEFAULT` = 30) — a finite pool for the whole visit. Raising it lets the player inspect more lots deeply across one visit.

Refill happens only at the lot boundary. When a lot is set, the reserve pays the **deficit** (`cap − current AP`) and no more: a weak lot left under-inspected preserves reserve for later lots — a built-in "don't over-inspect junk" incentive with no extra rules. If the reserve can't cover the full deficit it tops up as much as it can and goes to 0; once empty, no further refill occurs and later lots run on whatever AP is left.

```
Enter      AP 10 / Reserve 30
Lot1 -8    AP 2  → boundary: deficit 8  → AP 10 / Reserve 22
Lot2 -10   AP 0  → boundary: deficit 10 → AP 10 / Reserve 12
Lot3 -10   AP 0  → boundary: deficit 10 → AP 10 / Reserve 2
Lot4 -10   AP 0  → boundary: deficit 2 (reserve short) → AP 2 / Reserve 0
Lot5       only 2 AP, no further refill
```

Both values are resolved once at run construction through dedicated resolvers on `RunRecord`, the single fold point where future modifiers (car, attributes, perks) will enter. They are currently flat. The first lot of a visit opens at the full cap. This pool replaces the old per-lot fixed `action_quota`; a designer may still cap an individual lot below the pool maximum.

## Customer Scaling

Opening shop maps the selling-slot commitment to a nightly customer count, passed to the customer generator:

| Selling slots committed            | Customers |
| ---------------------------------- | --------- |
| 1 (Evening only, after an auction) | 2–3       |
| 2 (Afternoon + Evening)            | 4–6       |
| 3 (full day)                       | 7–10      |

Opening shop in slot 1 commits the whole day and yields max traffic; opening after an auction commits only the Evening for base traffic. The customer-sell mechanics themselves are unchanged — only the count is derived here (see `customer_sell.md`).

## Living Cost

Living cost (`Economy.DAILY_BASE_COST` = 100) is deducted once per calendar day during the day-end sequence, regardless of how the day's slots were spent. It is a property of the calendar day, not of slots.

## Persistence & Migration

Persisted on `SaveManager`: `current_slot`, `storage_ap`, `selling_slots_today`, and the `pending_run` economics dict, all deserialized behind `.has()` guards. Storage AP is effectively ephemeral — it refreshes at each Storage slot and resets to 0 at day-end. Per-clue `research_progress` persists on each `ItemEntry` and serializes with it. Auction AP (both tiers) is run-scoped: seeded at visit construction, cleared with run state, never persisted across sessions.

Legacy saves migrate cleanly: the old `research_slots` array (day-ticker lifecycle) is discarded, and any in-flight `research_days_spent` is converted into `research_progress` so partial work isn't lost. Because the live system no longer uses the rarity→days table, a frozen copy of it (`Economy.RESEARCH_DAYS`) is retained solely for that migration. Condition and revealed clues already persisted, so no in-progress item loses state.

## Invariants

- `MetaManager` is the **only** writer of `current_slot`, living cost, and the day-end sequence. The hub never deducts cost or generates customers itself.
- Storage AP is **per-slot**: full at each Storage slot start, discarded at slot end, never carried.
- Storage research is **deterministic** and must never call the on-site roll path (`ItemEntry.attempt_clue`). The two reveal paths stay separate — gamble at auction, grind in storage.
- Auction AP is **capped per lot** and pure-consume within a lot; it refills toward the cap (deficit only, partial when short) **only at lot boundaries**, stopping once the reserve empties.
- Living cost is **once per calendar day**, never per slot.

## Open Questions

- The AP cost table and pool sizes are flat and untuned; with stacked Storage slots, is 10 AP/slot too generous for full authentication, and should Restore cost more than Repair?
- Auction AP modifier levers (car, attributes, perks) have fold points reserved in `RunRecord` but no live terms — what raises the cap vs. the reserve?
