# Time-Slot Day Structure & Storage AP Economy

## Goal

Replace the hub phase's passive day-counter model with a **3-slot day** (morning, afternoon, evening) in which the player allocates each slot to one activity, and move storage work onto an action-point (AP) economy. Today the hub has no moment-to-moment agency — the player assigns an item, then clicks "day pass" repeatedly until timers tick down — and the run/hub boundary is all-or-nothing: go to auction (a whole-day commitment) or stay home advancing timers. The slot model lets a single day mix auction, storage, and selling, and the AP economy turns storage from a waiting game into a budgeted set of choices.

## Requirements

1. Replace atomic calendar days with a 3-slot day; the player allocates each slot to an activity (Auction, Storage, or Open Shop) from the hub.
2. Run storage actions on a per-slot AP pool instead of passive day-timers — a fresh pool each storage slot, so committing more slots to storage does proportionally more work (mirroring how committing more slots to selling raises customer traffic).
3. Make hidden-clue research deterministic — no success roll. Variance belongs at the time-pressured auction; in slow storage work, repeated bad luck only punishes a player who has already paid slots, AP, and living cost.
4. Replace the auction's per-lot fixed action quota with a two-tier inspection AP pool: a per-lot cap plus a reserve that tops the cap back up only at lot boundaries.
5. Scale nightly customer count with the number of slots the player commits to selling.
6. Preserve existing saves and in-progress item state (condition, revealed clues, partial research) across the change without losing player work.

## Design

### Slot Model

Each calendar day has three slots:

| Slot | Label     |
| ---- | --------- |
| 1    | Morning   |
| 2    | Afternoon |
| 3    | Evening   |

The three activities a slot can hold:

- **Auction** — Morning only. Consumes slots 1+2 (morning + afternoon): the player travels to the location, inspects/bids/loads cargo, and returns for the evening slot. One auction per day.
- **Storage** — The player works items with a fresh per-slot AP pool on Repair/Restore/Research. Available in any unallocated slot. Each storage slot grants its own full pool, so multiple storage slots in a day stack into proportionally more work.
- **Open Shop** — Triggers the nightly customer sell immediately and ends the day. Customer count depends on how many of the day's slots are committed to selling (see Customer Scaling).

Slot-flow examples:

- **Auction day:** Slot 1 = Auction, Slot 2 = locked to travel/auction, Slot 3 = free (Storage or Open Shop).
- **Storage-heavy day:** Slot 1 = Storage, Slot 2 = Storage, Slot 3 = Open Shop.
- **Full shop day:** Slot 1 = Open Shop — a 3-slot commitment: shop opens at once, maximum customers, day ends.
- **Mixed day:** Slot 1 = Storage, Slot 2 = Open Shop — a 2-slot commitment, moderate customers.

### Storage AP Economy

Storage actions consume AP from a **per-slot** pool, replacing the day-counter/tick model.

- **Pool size:** 10 AP per storage slot (flat; revisited after playtesting).
- **Refresh:** Full pool at the start of every Storage slot — not once per calendar day. A 2-storage-slot day grants 10 + 10 = 20 AP of total work.
- **Leftover:** Unspent AP is discarded when the slot ends; it never carries into the next slot.

Action costs and effects:

| Action       | AP Cost | Effect                                                                                                                                                                                                       |
| ------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Repair**   | 2 AP    | Condition rises by a base increment scaled by storage zone and item rarity, capped at 0.5.                                                                                                                   |
| **Restore**  | 2 AP    | Condition rises by a larger base increment scaled by storage zone, rarity, and the Restoration attribute, capped at 1.0.                                                                                     |
| **Research** | 4 AP    | Deterministic — no roll. Each spend adds `5 + Investigation attribute` progress toward one target hidden clue; the clue reveals when accumulated progress ≥ its DC. Unavailable when no hidden clues remain. |

Each action applies immediately on selection — no day-tick delay. One press applies one action's worth of effect.

**Per-slot budget math** — 10 AP is the budget for _one_ storage slot:

| Single-Slot Plan                     | AP Used | Notes                                  |
| ------------------------------------ | ------- | -------------------------------------- |
| 2× Research + 1× Repair              | 10      | Research-focused slot, exact fit       |
| 1× Restore + 1× Research + 1× Repair | 8       | Mixed slot, 2 AP leftover              |
| 1× Restore + 1× Restore + 1× Repair  | 6       | Condition-focused, 4 AP leftover       |
| 5× Repair                            | 10      | Full-condition push                    |
| 1× Restore + 1× Research             | 6       | Feasible, 4 AP leftover                |
| 1× Repair                            | 2       | Light maintenance, rest AP unused      |

A player who wants to do more spends _another slot_ on Storage for a fresh 10 AP — the cost is the auction or selling given up, not a shared daily ceiling.

> **Tuning note:** Restore currently costs the same 2 AP as Repair — the design intent was a higher Restore cost (4 AP), so this is a likely tuning target. These numbers were first calibrated against a shared daily pool; with 10 AP per slot (2–3 storage slots → 20–30 AP/day), both pool size and action costs need a retuning pass before release — 10/slot may make full authentication too cheap once slots are stacked.

**Why research is deterministic, not a roll:** variance belongs where there is tension and a clock — the on-site auction, where the inspection mechanic stays a gamble. Storage research is a slow, deliberate investment of slots, AP, and living cost; a fail-roll there only punishes commitment and produces "spent three slots, revealed nothing" feel-bad outcomes. Deterministic research gives a clean split — **gamble at the auction, grind in storage.** The clue's DC stays meaningful (it sets how much total research a clue costs) and the Investigation attribute still matters (it raises progress per AP), just without luck. Research progress accumulates per in-progress clue and persists across slots and days, so a single clue can be worked toward over several sessions.

### Auction AP Economy

Auction inspection AP is a **two-tier** pool, separate from the storage pool. It is consumptive within a lot and refills only at lot boundaries.

- **AP (cap 10):** the spendable budget for inspecting the _current_ lot. Hard-capped at 10 with no buffs — the cap is the burst lever. Within a single lot, AP is pure consume; once spent it does not regenerate mid-lot.
- **Refill Metric (reserve):** a finite reserve for the whole auction visit — the endurance lever.

Refill cadence — at lot boundary only:

1. The player inspects the current lot, spending AP down (possibly to 0).
2. When the lot's auction ends, AP refills back toward the cap from the Refill Metric, paying only the **deficit** (`cap − current AP`).
3. The next lot begins with the refilled AP.
4. When the Refill Metric is empty, no refill happens — later lots run on whatever AP is left, eventually reaching 0.
5. **Partial refill:** if the reserve can't cover the full deficit, it tops up as much as it can and goes to 0 (it never refuses to refill).

The two tiers are independent levers: raising the **cap** deepens inspection of any single lot (never exceeding the cap within one lot, no matter how full the reserve); raising the **Refill Metric** lets the player inspect more lots deeply across one visit. Because refill only pays the deficit, **under-spending on a weak lot preserves the reserve for later good lots** — a built-in "don't over-inspect junk" incentive with no extra rules.

Worked example (cap 10, Metric 30):

```
Enter      AP 10 / Metric 30
Lot1 -8    AP 2  → end: refill deficit 8  → AP 10 / Metric 22
Lot2 -10   AP 0  → end: refill deficit 10 → AP 10 / Metric 12
Lot3 -10   AP 0  → end: refill deficit 10 → AP 10 / Metric 2
Lot4 -10   AP 0  → end: refill deficit 2 (reserve short) → AP 2 / Metric 0
Lot5       only 2 AP available, no further refill
```

This replaces the current per-lot fixed action quota: inspection is no longer gated by a number stored on each lot, but by the shared two-tier pool, capped per lot. A specific lot may still cap below the pool maximum if a designer wants it tighter.

### Customer Scaling by Slot Commitment

When the player opens shop, nightly customer count scales with the slots committed to selling:

| Slots Committed            | Customer Count | Description                      |
| -------------------------- | -------------- | -------------------------------- |
| 1 (evening, after auction) | 2–3            | Quick evening sale, base traffic |
| 2 (afternoon + evening)    | 4–6            | Moderate window, bonus 1–2       |
| 3 (full day)               | 7–10           | Full-day commitment, max traffic |

The committed slot count drives how many customers arrive that night. Opening shop in slot 1 ends the day immediately with full 3-slot traffic (the player is committing the whole day); opening after an auction (evening only) gives 1-slot traffic.

### Living Cost

Living cost stays per calendar day, not per slot — a day is a calendar day regardless of how its slots are spent.

### Hub Presentation

The hub drops the Day Pass control and presents a **slot tray**: three slots with filled/empty indicators. Each unfilled slot offers an activity chooser — Auction, Storage, Open Shop. Auction is selectable only in slot 1 and is otherwise greyed with a tooltip. After a slot is allocated the hub re-renders for the next slot; after the final slot is spent, or whenever Open Shop is chosen, the day transitions to the day summary.

Layout sketch:

```
[Day 7]          [● Slot 1: Morning]  [○ Slot 2: Afternoon]  [○ Slot 3: Evening]
                 [Auction] [Storage] [Open Shop]

[Mastery: R3]  [$ 12,450]  [Storage: 8/20]
```

### State Persistence

- Storage AP is ephemeral: it refreshes to full at the start of each storage slot and any leftover is discarded when the slot ends — it never persists or carries between slots.
- Research progress per hidden clue persists across slots and days, so a clue can be revealed over multiple work sessions.
- Auction AP (both tiers) is scoped to one auction visit and resets when a new visit starts; it is not preserved mid-visit across sessions, consistent with a run being a single sitting.
- The day summary reflects how many slots were used and how many storage actions were taken.
- Existing saves and in-progress items carry over without losing work: condition and already-revealed clues are preserved, and any partial research in flight is converted into starting progress under the new model rather than discarded.

## Non-Goals

1. Do not redesign the nightly customer sell mechanics beyond making customer count scale with slot commitment.
2. Do not change the on-site auction inspection mechanic — it stays a roll. Only storage research becomes deterministic.
3. Do not add AP or endurance progression levers yet (perks, vehicle upgrades, attribute thresholds that raise the storage pool, the auction cap, or the Refill Metric) — all pool sizes are flat for this pass.
4. Do not move living cost to per-slot; it stays per calendar day.
5. Do not change how anchor/surface clues or appraisal pricing work.

## Acceptance Criteria

1. A day is three slots; the player allocates each to Auction, Storage, or Open Shop, and an auction consumes the morning and afternoon slots and returns the player for the evening.
2. Storage actions execute immediately on selection and consume AP from a pool that is full at the start of each storage slot; a two-storage-slot day provides two full pools.
3. Storage actions are unavailable when AP is insufficient or the action does not apply (condition already at its repair cap, or no hidden clues remain).
4. Research always converts AP into progress and never fails a reveal; a hidden clue reveals once its accumulated progress reaches its DC, and progress carries across slots and days.
5. Auction inspection AP is capped per lot, never regenerates within a lot, and refills toward the cap — paying only the deficit, partial when the reserve is short — only at lot boundaries, stopping once the reserve is empty.
6. Nightly customer count matches the number of slots committed to selling.
7. Choosing Open Shop ends the day from whatever slot it is chosen in.
8. Living cost is deducted once per calendar day, not per slot.
9. Existing saves load without error and in-progress items retain their condition, revealed clues, and partial research.
10. The day summary reflects the day's slot usage and storage activity.
