# Time-Slot Day Structure & Storage AP Economy

## Problem

The hub phase has two problems. Storage actions run on passive day-counters with no player agency — the player assigns an item, then clicks "day pass" repeatedly until timers tick down. Meanwhile, the run/hub boundary is binary: the player either goes to auction (consumes one or more full days) or stays home with nothing interesting to do besides advance timers.

## Solution Overview

Replace atomic days with a **3-slot day** (morning, afternoon, evening). Each slot the player allocates to one activity. Storage actions cost **AP** from a daily pool instead of running on day-timers. Customer count scales with slots committed to selling.

## Slot Model

Each calendar day has three slots:

| Slot | Label     |
| ---- | --------- |
| 1    | Morning   |
| 2    | Afternoon |
| 3    | Evening   |

The player allocates each slot from the hub. The three activities:

- **Auction** — Morning only. Consumes slots 1+2 (morning + afternoon). Player travels to the location, inspects/bids/loads cargo, and returns for the evening slot. Only one auction per day.
- **Storage** — Player enters the storage scene, spends AP from the daily pool on Repair/Restore/Research. Available in any unallocated slot. Multiple storage slots in one day let the player check progress and do more work.
- **Open Shop** — Triggers the customer sell scene immediately and ends the day. Customer count is determined by how many of the 3 slots are being committed to selling (see Customer Scaling below).

### Slot Flow by Example

**Auction day:** Slot 1 = Auction, Slot 2 = (auto-locked as travel/auction), Slot 3 = free (Storage or Open Shop).

**Storage-heavy day:** Slot 1 = Storage, Slot 2 = Storage, Slot 3 = Open Shop.

**Full shop day:** Slot 1 = Open Shop (3-slot commitment: player opens immediately, gets max customers, day ends).

**Mixed day:** Slot 1 = Storage, Slot 2 = Open Shop (2-slot commitment, moderate customers).

## Storage AP Economy

Storage actions consume AP from a daily pool. This replaces the current day-counter/tick model.

### AP Pool

- **Size:** 10 AP per day (flat; revisited after playtesting)
- **Refresh:** Full pool at the start of each calendar day (after day summary)
- **Tracking:** `SaveManager` field + display in storage scene header

### Action Costs & Effects

| Action       | AP Cost | Effect                                                                                                                                                        |
| ------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Repair**   | 3 AP    | Condition += `REPAIR_BASE * zone_factor * rarity_factor`, capped at 0.5. Uses existing `ResearchSlot.apply_repair()` math.                                    |
| **Restore**  | 4 AP    | Condition += `RESTORE_BASE * zone_factor * rarity_factor * (1 + restoration_attr * 0.4)`, capped at 1.0. Uses existing `ResearchSlot.apply_restore()` math.   |
| **Research** | 5 AP    | One attempt to reveal a hidden clue. Rolls `attempt_clue(clue, attribute_bonus)` against the clue's DC. If no hidden clues remain, the action is unavailable. |

### Per-Day Budget Math

With 10 AP and the costs above:

| Daily Plan                               | AP Used | Notes                          |
| ---------------------------------------- | ------- | ------------------------------ |
| 2× Repair + 1× Research                  | 11      | Over budget — must drop one    |
| 1× Restore + 1× Research                 | 9       | Feasible, 1 AP waste           |
| 3× Repair                                | 9       | Full condition day, 1 AP waste |
| 2× Research (attempts)                   | 10      | Full research day              |
| 1× Restore + 1× Repair                   | 7       | Mixed, 3 AP leftover           |
| 1× Repair (+ evening slot after auction) | 3       | Light evening maintenance      |

The intent is that 10 AP forces meaningful choices but doesn't feel stingy. Leftover AP is fine — it's lost at day end.

### UI Impact on Storage Scene

Current storage scene (`game/meta/storage/storage_scene.gd`): three action buttons (Repair, Research, Restore) that call `MetaManager.assign_research_slot()`. Under the new model:

1. Each button deducts AP on press instead of assigning a slot
2. A persistent AP bar at the top shows `AP: 8 / 10`
3. Buttons are grayed out when AP < cost or the action is inapplicable (e.g., condition already ≥ 0.5 for Repair, no hidden clues left for Research)
4. The action executes immediately — no day-tick delay
5. Completed actions emit the same knowledge XP events as the current tick model
6. Remove the old `ResearchSlot` day-ticker — `_tick_research_slots()` is deleted from `MetaManager`

### Per-Action Cadence vs. Day Ticks

Currently, Repair/Restore apply incremental gains per day-tick. In the AP model, each button press applies one tick's worth of gain. Research previously took 1-5 calendar days and auto-revealed ALL hidden clues on completion. Now each 5-AP attempt tries to reveal one hidden clue, with the success roll determined by attributes vs. clue DC — consistent with the inspection scene's `attempt_clue()` mechanic.

**Items already in-progress:** On migration, convert days-remaining for Research into a fraction (research_days_spent / RESEARCH_DAYS[rarity]) × hidden_clue_count, rounded down as already-revealed clues. For Repair/Restore, no conversion needed — condition is already tracked as a float.

## Customer Scaling by Slot Commitment

When the player chooses "Open Shop," the number of daily customers scales with slots consumed:

| Slots Committed            | Customer Count | Description                      |
| -------------------------- | -------------- | -------------------------------- |
| 1 (evening, after auction) | 2–3            | Quick evening sale, base traffic |
| 2 (afternoon + evening)    | 4–6            | Moderate window, bonus 1–2       |
| 3 (full day)               | 7–10           | Full-day commitment, max traffic |

**Mechanic:** When the player clicks "Open Shop," the slot count is passed through to `MetaManager._generate_nightly_customers(count_hint)`. The existing `Customer.generate_for_night()` already accepts a count override — wire it.

**Open Shop from any slot:** If the player opens shop in slot 1, the day ends immediately with 3-slot-equivalent customers (the player is committing the entire day). If after auction (slot 3 only), they get 1-slot customers.

## Living Cost

Stays at `DAILY_BASE_COST × 1 day` — not per-slot. A day is a calendar day.

## Hub UI Changes

Current hub: buttons for Storage, Sell, Vehicle, Knowledge, Next Run, Day Pass. Slot model changes:

1. Remove **Day Pass** button and `day_pass_dialog.tscn`
2. Add **Slot Tray** — shows 3 slots (filled/empty indicators). Each unfilled slot shows available actions.
3. Add **Activity Chooser** per unfilled slot: [Auction] [Storage] [Open Shop]
4. Auction button (slot 1 only) — greys out with tooltip if not slot 1
5. Next Run is replaced by Auction (slot 1 choice)
6. Storage and Sell buttons are replaced by slot-based choices

**Hub layout sketch:**

```
[Day 7]          [● Slot 1: Morning]  [○ Slot 2: Afternoon]  [○ Slot 3: Evening]
                 [Auction] [Storage] [Open Shop]

[Mastery: R3]  [$ 12,450]  [Storage: 8/20]
```

After allocating slot 1, the hub re-renders for slot 2, etc. After slot 3 (or Open Shop from any slot), transitions to day summary.

## Day Summary Changes

`DaySummary` gains:

- `slots_used: int` (1-3)
- `storage_actions_taken: int` (sum of Repair + Restore + Research actions performed)
- Existing `completed_actions` array still records each action for display

No structural changes to the summary scene itself — just new data fields.

## Save Format Changes

`SaveManager` gains:

- `current_slot: int` (0 = day hasn't started, 1-3 = current slot index)
- `storage_ap: int` (current AP available for storage)
- Remove: `research_slots` array (the old day-ticker slots) — replaced by ephemeral per-action execution
- Migration: detect legacy `research_slots` on load and discard. Items' condition and `revealed_clue_ids` are already persisted — no data loss.

## Open Questions (Resolved)

1. **Shared vs. separate AP?** — Separate. Inspection uses per-lot `actions_remaining` from `lot_data.action_quota`. Storage uses a daily pool. Different contexts, no shared pool needed.
2. **Daily AP pool scaling?** — Flat 10 AP/day. Revisit after base flow is playable. Candidate progression levers: perks that add +2 AP, vehicle-upgrade unlocks, attribute threshold bonuses.
3. **Customer count curves?** — 1 slot: 2–3, 2 slots: 4–6, 3 slots: 7–10. Verified after playtesting.

## Implementation Order

| Step | Description                                                                                                                                                                        | Files Impacted                                                    |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| 1    | Add `storage_ap` to SaveManager, MetaManager, and DaySummary. Expose as `MetaManager.storage_ap` / `MetaManager.max_storage_ap`                                                    | `save_manager.gd`, `meta_manager.gd`, `day_summary.gd`            |
| 2    | Add AP bar to storage scene UI. Modify `_assign_action()` to deduct AP and execute immediately (no slot assignment). Gray out buttons when AP insufficient or action inapplicable. | `storage_scene.gd`, `storage_scene.tscn`                          |
| 3    | Delete `ResearchSlot` day-ticker logic. Remove `_tick_research_slots()` from MetaManager. Remove `assign_research_slot()` / `remove_research_slot()`.                              | `meta_manager.gd`, `research_slot.gd` (or inline)                 |
| 4    | Build slot tray + activity chooser into hub. Remove Day Pass button + dialog. Wire Auction → location select, Storage → storage scene, Open Shop → customer sell with slot count.  | `hub_scene.gd`, `hub_scene.tscn`, `day_pass_dialog.tscn` (delete) |
| 5    | Modify `_generate_nightly_customers()` to accept slot count.                                                                                                                       | `meta_manager.gd`, `customer.gd`                                  |
| 6    | Update DaySummary to capture per-slot data. Verify summary scene displays new fields gracefully when missing.                                                                      | `day_summary.gd`, `day_summary_scene.gd`                          |
| 7    | Add save migration: detect legacy `research_slots`, discard them, set fresh defaults.                                                                                              | `save_manager.gd`                                                 |
| 8    | Tuning pass: AP pool size, action costs, customer curves. Remove debug logging.                                                                                                    | —                                                                 |

## Post-Implementation Validation

- Storage actions execute immediately on button press and consume AP
- AP bar updates correctly and grays out buttons appropriately
- Auction consumes 2 slots, returns for evening
- Customer count matches slot commitment
- Open Shop from any slot ends the day
- Living cost deducted once per day (not per slot)
- Legacy saves load without error, old research_slots silently discarded
- Day summary correctly reflects the day's activity
