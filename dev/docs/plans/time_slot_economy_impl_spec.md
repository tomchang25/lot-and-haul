# Implementation Spec — Time-Slot Day Structure & Storage AP Economy

> Generated from `time_slot_economy.md` (the Plan) plus codebase exploration. This is an ephemeral, code-coupled artifact: archive it once the work merges. Plan = what/why; this spec = where/how-wired.

## Goal

Replace atomic calendar days with a 3-slot day, move storage work onto a per-slot AP economy with deterministic research, and convert the auction's per-lot fixed action quota into a two-tier AP pool (cap + reserve). Customer count scales with slots committed to selling.

## Relational Context

- **`MetaManager` is the single authority for day/slot progression.** Today `advance_days(days)` increments `SaveManager.current_day`, deducts `days × Economy.DAILY_BASE_COST`, runs `_tick_research_slots(days)`, captures `customer_sales_today`, calls `_generate_nightly_customers()`, and `SaveManager.save()`. After this change a day is always exactly one calendar day ending after slot 3 or any Open Shop; the multi-day tick path is retired. Keep MetaManager the only writer of `current_day`, living cost, and the day-end sequence — do not let the hub deduct cost or generate customers itself.
- **`SaveManager` owns persisted state; `MetaManager` mutates it.** New persisted fields (`current_slot`, `storage_ap`) follow the existing pattern: declare on SaveManager, add to the `save()` dict, deserialize with a `.has()` guard. `research_slots` leaves the schema.
- **`RunRecord` (`common/gameplay/run_record.gd`) owns auction AP; `RunManager.run_record` is the live instance.** `InspectionScene` already spends AP by mutating `RunManager.run_record.actions_remaining` (costs `UNVEIL_COST = 1`, `CLUE_CHAIN_COST = 2`) and finishes when it reaches 0. The per-lot budget is currently read from `RunManager.run_record.lot_entry.lot_data.action_quota`. **The lot boundary is `RunRecord.set_lot(entry)`** (called from `lot_browse_scene._on_enter_pressed()`), which today hard-resets `actions_remaining = action_quota`. This is the single refill point — change it to refill toward the cap from the reserve; do not add a second reset elsewhere.
- **`ItemEntry` (`common/gameplay/item_entry.gd`) owns per-item clue/condition state** (`condition`, `revealed_clue_ids`, `anchor_revealed`, computed `verified`) and serializes via `to_dict()`/`from_dict()`. Per-clue research progress is new state and must live here and be serialized here.
- **Two reveal paths must stay separate.** `ItemEntry.attempt_clue(clue, attribute_bonus)` is the on-site **roll** (`success_chance = clamp((21 + attr - dc) * 5, 5, 95)`), called only by `InspectionScene`. Storage research must use a new **deterministic** path and must never call `attempt_clue`. Today storage reveal is `entry.reveal_all_hidden()` fired from `_tick_research_slots` on completion; that atomic reveal is replaced by per-clue progress.
- **`ResearchSlot` (`common/gameplay/research_slot.gd`) carries two unrelated responsibilities.** (a) the day-ticker slot lifecycle (`item_id`, `action`, `completed`, `research_days_spent`, `check_assignable`) and (b) the static condition math (`apply_repair`, `apply_restore`, with `REPAIR_BASE`, `RESTORE_BASE`, zone/rarity factors, `RESTORE_ATTR_COEFF`). Keep the math, retire the lifecycle. Do not delete `apply_repair`/`apply_restore`.
- **Storage UI call direction inverts.** Today `storage_scene.gd` buttons call `_assign_action(...)` → `MetaManager.assign_research_slot()` / `remove_research_slot()`, and the effect lands later during a day tick. After: each button spends AP and applies its effect **immediately** through a new MetaManager call; there is no slot to assign or remove.
- **Customer count is derived by MetaManager, fulfilled by Customer.** `Customer.generate_for_night(rng, storage_items, count, all_clue_ids)` already honors an explicit `count`. Today `MetaManager._generate_nightly_customers()` omits it (defaults to 3–5). After: MetaManager maps slots-committed-to-selling → a count and passes it through. `customer_sell_scene.gd` reads `SaveManager.nightly_customers` unchanged.
- **Navigation goes through `GameManager`** (`go_to_storage`, `go_to_location_select`, `go_to_customer_sell`, `go_to_day_summary(summary)` via the `_pending_day_summary` hand-off). The hub wires slot choices to these existing entry points; no new navigation mechanism.
- **Attributes read through `KnowledgeManager.get_attribute_value(id)`** (default 1). Restoration already feeds `apply_restore`; Investigation feeds the new research-progress rate.

## Scope

### Included

- Per-slot storage AP pool; immediate Repair/Restore/Research execution.
- Deterministic per-clue research progress and reveal.
- Two-tier auction AP (per-lot cap + Refill Metric, deficit refill at lot boundary).
- 3-slot day in the hub; removal of Day Pass; end-of-day after slot 3 or Open Shop.
- Customer count scaled by slot commitment.
- Save migration: discard `research_slots`, seed `research_progress`.

### Excluded

- AP/cap/reserve progression levers (perks, vehicle, attribute thresholds) — flat values.
- Any change to the on-site inspection roll mechanic.
- Customer sell mechanics beyond count.
- Anchor/surface clue and appraisal pricing logic.
- Final balance tuning (tracked as a separate tuning pass).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoload/meta_manager.gd` | Large | Retire `advance_days(days)`/`_tick_research_slots`; add single end-of-day, per-slot storage AP actions, slot→customer-count mapping; remove `assign_research_slot`/`remove_research_slot`. |
| `game/meta/hub/hub_scene.gd` + `.tscn` | Large | Slot tray + activity chooser; remove Day Pass wiring; route Auction/Storage/Open Shop; trigger end-of-day. |
| `game/meta/storage/storage_scene.gd` + `.tscn` | Large | AP bar; buttons spend AP and apply immediately; gray-out on insufficient AP / inapplicable; drop slot-assignment UI. |
| `common/gameplay/item_entry.gd` | Medium | Add per-clue `research_progress`; deterministic add-progress + single-clue reveal; serialize it; leave `attempt_clue` untouched. |
| `common/gameplay/research_slot.gd` | Medium | Keep `apply_repair`/`apply_restore` (and constants); remove slot lifecycle (`research_days_spent`, `completed`, assignment `check_assignable`). |
| `global/constants/economy.gd` | Small | Add `STORAGE_AP_MAX`, `REPAIR_AP_COST`, `RESTORE_AP_COST`, `RESEARCH_AP_COST`; retire `RESEARCH_DAYS` (migration keeps a frozen local copy of the legacy table). |
| `global/autoload/save_manager.gd` | Medium | Add `current_slot`, `storage_ap`; remove `research_slots` from schema; migration to discard legacy slots and seed `research_progress`. |
| `common/gameplay/run_record.gd` | Medium | Add `inspection_ap_cap` + `refill_metric`; change `set_lot()` from hard reset to deficit refill toward cap. |
| `global/autoload/run_manager.gd` | Small | Initialize cap + reserve at auction-visit start; reset on `clear_run_state()`. |
| `game/run/inspection/inspection_scene.gd` | Small | Use the per-lot cap (not `action_quota`) as the HUD max; AP spend path unchanged. |
| `data/definitions/lot_data.gd` | Small | Retire `action_quota` as the pool source; optionally keep as an opt-in per-lot cap override. |
| `common/gameplay/day_summary.gd` | Small | Add `slots_used`, `storage_actions_taken`. |
| `game/meta/day_summary/day_summary_scene.gd` | Small | Display new fields; degrade gracefully when absent. |
| `game/meta/hub/day_pass_dialog/` (script + `.tscn`) | Delete | Remove the dialog entirely. |

## Implementation Notes

**Storage AP (MetaManager + storage_scene).** AP is per Storage *slot*, not per day: `MetaManager` refreshes `storage_ap` to `Economy.STORAGE_AP_MAX` (10) when a Storage slot begins and discards any leftover when the slot ends — AP never carries across slots. Cost constants live in `economy.gd` next to `STORAGE_AP_MAX`:

| Action | Constant | AP Cost |
| --- | --- | --- |
| Repair | `REPAIR_AP_COST` | 2 |
| Restore | `RESTORE_AP_COST` | 4 |
| Research | `RESEARCH_AP_COST` | 4 |

Each Storage button maps to one immediate-execution MetaManager method — there is no slot to assign. The old `storage_scene.gd` path (`_assign_action` → `MetaManager.assign_research_slot` / `remove_research_slot`, plus `_populate_tasks` task cards and the Remove button) is deleted; buttons call the new methods and the scene re-renders. Every method follows the same **guard → apply → charge** shape, and AP is charged *after* the effect lands, so a disabled or no-op action never costs AP:

*Repair* — press Repair → `MetaManager.repair_item(entry)`:

1. Guard: `storage_ap >= REPAIR_AP_COST` and `not ResearchSlot.is_repair_complete(entry)` (condition < 0.5). Button disabled otherwise.
2. Apply: `ResearchSlot.apply_repair(entry)` — raises condition toward the 0.5 cap and emits the REPAIR XP event.
3. Charge: `storage_ap -= REPAIR_AP_COST` (2).

*Restore* — press Restore → `MetaManager.restore_item(entry)`:

1. Guard: `storage_ap >= RESTORE_AP_COST`, condition ≥ 0.5, and `not ResearchSlot.is_restore_complete(entry)` (condition < 1.0).
2. Apply: `ResearchSlot.apply_restore(entry)` — raises condition toward 1.0 using the Restoration attribute and emits the RESTORE XP event.
3. Charge: `storage_ap -= RESTORE_AP_COST` (4).

*Research* — press Research → `MetaManager.research_item(entry)`:

1. Guard: `storage_ap >= RESEARCH_AP_COST` and at least one hidden clue is still unrevealed.
2. Apply: advance progress on the target hidden clue by `5 + KnowledgeManager.get_attribute_value("investigation")` (deterministic — never `attempt_clue`); when progress ≥ `clue.dc`, reveal it (append to `revealed_clue_ids`, emit the REVEAL XP event). See the deterministic-research note below for the per-clue progress store.
3. Charge: `storage_ap -= RESEARCH_AP_COST` (4).

Reuse `ResearchSlot.apply_repair`/`apply_restore` directly — they already enforce the 0.5 / 1.0 caps and read the Restoration attribute. After any action MetaManager saves and `storage_scene.gd` re-renders the AP bar, the detail panel, and each button's enabled/visible state (Repair/Restore mutual exclusion is unchanged).

**Deterministic research (item_entry).** This is the day-count → progress refactor: the old model (`ResearchSlot.research_days_spent` ticked against `Economy.RESEARCH_DAYS[rarity]`, then an atomic `reveal_all_hidden()`) is replaced by per-clue accumulated progress revealed one clue at a time. Add `research_progress: Dictionary` (clue_id → int) on `ItemEntry`. Research targets one hidden clue; each spend (cost `RESEARCH_AP_COST`) adds `5 + KnowledgeManager.get_attribute_value("investigation")` to that clue's progress; reveal it (append to `revealed_clue_ids`, grant a REVEAL XP event) once progress ≥ `clue.dc`. No roll, never `attempt_clue`. The action is unavailable when all `_hidden_clues()` are revealed. Serialize `research_progress` in `to_dict`/`from_dict`.

**Auction two-tier AP (run_record + run_manager).** Add `inspection_ap_cap` (10) and `refill_metric` to RunRecord. In `set_lot()`, replace `actions_remaining = action_quota` with a deficit refill: `deficit = cap - actions_remaining; take = min(deficit, refill_metric); actions_remaining += take; refill_metric -= take`. On the first lot of a visit `actions_remaining` starts at the cap. Within-lot spending is unchanged. When `refill_metric` is 0 no top-up occurs. RunManager seeds cap + reserve when a visit begins and clears them in `clear_run_state()`. The inspection HUD max becomes the cap.

**Day structure (hub + meta_manager).** Hub tracks `current_slot` (1–3). Auction is slot-1 only and consumes slots 1+2. Open Shop ends the day immediately from any slot. End-of-day (new MetaManager method) advances `current_day` by 1, deducts `Economy.DAILY_BASE_COST` once, captures `customer_sales_today`, calls `_generate_nightly_customers(count)`, saves, returns a `DaySummary`, then `GameManager.go_to_day_summary`. Do not deduct cost per slot.

**Customer count.** Map committed selling slots → count before generation: 1 → randi(2,3), 2 → randi(4,6), 3 → randi(7,10). Pass as the `count` arg of `Customer.generate_for_night`.

**Migration (save_manager).** On load: if `research_slots` is present, discard it. For an item mid-research under the old model, seed `research_progress` so spent effort isn't lost — convert `research_days_spent` against the legacy duration into already-revealed hidden clues, remainder into progress on the next clue. Because `Economy.RESEARCH_DAYS` is retired, the migration keeps a frozen local copy of that rarity→days table rather than reading the live constant. `condition` and `revealed_clue_ids` already persist — no loss. Auction AP is run-scoped and never persisted.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Storage action with AP < cost | Button disabled; no-op. |
| Research with no hidden clues left | Research unavailable for that item. |
| Condition already ≥ 0.5 | Repair hidden/disabled; Restore offered (existing mutual-exclusion logic). |
| Condition ≥ 1.0 | Both Repair and Restore disabled. |
| Refill Metric < deficit at lot boundary | Partial top-up; reserve goes to 0; later lots run on leftover AP. |
| Refill Metric empty | No refill; inspection proceeds on remaining AP. |
| Open Shop from slot 1 | Day ends now with 3-slot customer count. |
| Open Shop after auction (evening only) | 1-slot customer count. |
| Mid-day save/load (e.g. slot 2 allocated) | `current_slot`/`storage_ap` restore the in-progress day. |
| Legacy save with `research_slots` | Discarded; partial research seeded into `research_progress`. |

## Acceptance Criteria

1. A day is three slots; Auction consumes morning+afternoon and returns the player for evening; Storage and Open Shop allocate per slot.
2. Storage actions execute immediately and draw from a pool that is full at each Storage slot start; a two-storage-slot day yields two full pools.
3. Storage actions are unavailable when AP is insufficient or the action does not apply.
4. Research always converts AP into progress, never fails a reveal, reveals a clue at progress ≥ DC, and persists progress across slots and days.
5. Auction AP is capped per lot, never regenerates within a lot, and refills toward the cap (deficit, partial when short) only at lot boundaries until the reserve empties.
6. Nightly customer count matches slots committed to selling.
7. Open Shop ends the day from any slot.
8. Living cost is deducted once per calendar day.
9. Legacy saves load without error; in-progress items keep condition, revealed clues, and partial research.
10. The day summary reflects slot usage and storage activity.
