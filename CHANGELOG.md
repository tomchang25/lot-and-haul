# Changelog

Append-only record of shipped work. This is the project's permanent "done" history.

**Why this file exists:** it is the single home for "what got built." Because it is append-only — you only ever add entries, never reconcile them against current code — it cannot go stale. This is what lets every other tracking surface stay forward-only: `systems/` describes the system as it *is* (present tense, no Done lists) and `TODO.md` holds only open work (`## Active` in-flight flows, `Plan`/`Chore`/`Bug`, and `## Draft` concepts), with multi-step flows detailed in `dev/docs/plans/` files. When a phase ships, append one entry here, then cut that phase from its plan file; when a whole flow ships, also delete its `TODO.md` line.

This file is the single source of truth for the entry format. Each entry: `- YYYY-MM-DD — [scope] one-line summary (commit/PR ref)`. Group related entries under a `## <Title>` heading — title only, no "Phase"/"Stage" wording.

---

## Live Budget Label

- 2026-05-31 — [auction] Budget label pinned to top-right corner showing remaining cash minus committed run costs; refreshes live after every player bid

## Time-Slot Day Structure & Storage AP Economy

- 2026-05-30 — [day-structure] 3-slot day (Morning/Afternoon/Evening); hub slot tray replaces Day Pass; Auction consumes slots 1+2, returns player for Evening
- 2026-05-30 — [day-structure] Storage AP economy: per-slot pool of 10 AP, refreshed each Storage slot; Repair (2 AP), Restore (2 AP), Research (4 AP) execute immediately
- 2026-05-30 — [day-structure] Deterministic storage Research: fixed (5 + Investigation) progress per AP spend, reveals clue at accumulated progress ≥ DC; `ItemEntry.research_progress` persists across slots and days
- 2026-05-30 — [day-structure] Two-tier auction AP: `inspection_ap_cap` (10) per-lot cap + `refill_metric` (30) reserve; deficit refill at lot boundaries; HUD max uses cap instead of `action_quota`
- 2026-05-30 — [day-structure] Open Shop scales nightly customer count by selling-slot commitment: 1→2–3, 2→4–6, 3→7–10
- 2026-05-30 — [day-structure] `end_day()` replaces `advance_days()`; always advances exactly one calendar day; folds pending run economics from `resolve_run()`
- 2026-05-30 — [day-structure] `resolve_run()` returns void; stashes run economics as pending, sets slot=3 (Evening), navigates to hub; day summary fires from hub when day ends
- 2026-05-30 — [day-structure] Save migration: `research_slots` array retired; partial `research_days_spent` seeded into `ItemEntry.research_progress`; `current_slot`, `storage_ap`, `selling_slots_today` added to schema
- 2026-05-30 — [day-structure] `ResearchSlot` lifecycle stripped (enums, dicts, slot management); math helpers (`apply_repair`, `apply_restore`, caps) kept

## Day Summary Rework

- 2026-05-29 — [day-summary] `DaySummary` carries customer sales total/detail; `advance_days()` captures `customer_sales_today` before the nightly ledger clears; net change includes sales revenue; summary scene renders a customer-sales section; post-run routes through the day-summary scene (`f873cc7`).

## Value Policy Cleanup

- 2026-05-29 — [pricing] `item_price` simplified to `(appraised|verified) × condition_multiplier`; `MarketManager`, `PriceConfig`, `ItemViewContext` removed; condition kept as an independent ×0.25–×4.0 system (`41a5945`).

## Unified Customer Selling

- 2026-05-29 — [customer-sell] `Customer` runtime type with match-biased nightly generation, `SellMath` conservative/aggressive helpers, customer-sell scene with car-grid packing + dice UI, `customer_sales_today` ledger (`236f636`).
- 2026-05-29 — [cleanup] Legacy merchant negotiation, special orders, and deprecated selling helpers removed; `ItemEntry` price logic deduplicated, research moved to `ResearchSlot` (`9b4dfe9`, #108).

## YAML Content Regeneration

- 2026-05-28 — [content] All 128 clues rewritten to 1-word `known_text` with naming entries assigned; validator enforces body+qualifier; names reconciled (`19c6caf`).

## Dynamic Naming Rules

- 2026-05-28 — [naming] Priority-based `display_name` composition from naming clues, 3-word `known_text` ceiling, full-reveal validation (`3c4c423`).

## Inspection Refinement

- 2026-05-28 — [inspection] `DisplayState` (veiled/unveiled/verified), clue chain reveal, lot unveil probability; `verified` as a computed property (`e59d58e`).

## Clue Independence + Attribute System

- 2026-05-27 — [items] Identity layers and the skill system replaced by clue-based add-then-mul pricing, 5 SPECIAL attributes, and dice-roll inspection; `ItemData.base_price` deprecated (`1ff40d0`, #107).

## Cargo Scene Refactor

- 2026-05-25 — [cargo] Two-column layout with scrollable item list (`CargoItemRow`), value/weight/condition/shape legibility, inline trailer slots, run summary panel; 10×4 temp grid removed (`0113112`).

## Storage Authenticate

- 2026-05-14 — [storage] Hub final-layer resolution and Storage Authenticate: verified flag, rarity-based duration, slot action (`4190a4b`).

## Foundations

- 2026-05-04 — [items] Pre-redesign foundations: item/entry data model, veil/identity-layer inspection, AP-grid inspection, runtime veil cleanup. The veil and identity-layer models were later superseded by the clue system above.

## Hub & Home

- 2026-05-01 — [hub] Hub scene with Next Run / Storage / Sell / Vehicle / Knowledge / Day Pass navigation buttons
- 2026-05-01 — [hub] Header displaying Mastery Rank, Balance, and Storage item count
- 2026-05-01 — [hub] Day Pass confirmation dialog routes through `MetaManager.advance_days(1)` to `DaySummaryScene`
- 2026-05-01 — [hub] Vehicle button replaces Van info popup; routes to `GameManager.go_to_vehicle_hub()`
- 2026-05-01 — [hub] `_refresh_display()` refreshes header on return from `DaySummaryScene`
- 2026-05-01 — [hub] Knowledge Hub entry scene routing to Mastery / Attributes / Perks sub-panels
- 2026-05-01 — [day-summary] `DaySummaryScene` shared by hub day-pass and run-review flows; reads from `GameManager.consume_pending_day_summary()`, falls back to hub if empty
- 2026-05-01 — [day-summary] `DaySummary` value object with `start_day` / `end_day` / `days_elapsed`, run fields, `cargo_count`, `living_cost`, `completed_actions`, `net_change`, `has_run_data()` gate
- 2026-05-01 — [day-summary] `DaySummary.cargo_count` + regrouped scene (TripExpensesGroup / DailyGroup / CargoCountLabel); trip expenses, daily living, cargo summary no longer share a column
- 2026-05-01 — [storage] Storage scene with research-slot assignment (Repair / Restore / Research), slot removal, per-action disabled-reason tooltips
- 2026-05-01 — [storage] `Column.RESEARCH_STATUS` on storage list reflects current slot action or completion state
- 2026-05-01 — [storage] Hub Storage button badge shows `"Storage (N done)"` when research slots complete; refreshed on `_refresh_display()`
- 2026-05-01 — [hub] Sell button routes to customer-sell scene; replaces old Merchant button

## Knowledge

- 2026-05-01 — [knowledge] `SaveManager.category_points` / `attribute_levels` / `unlocked_perks` persistence
- 2026-05-01 — [knowledge] Four-layer mastery model: `get_category_rank()`, `get_super_category_rank()`, `get_mastery_rank()`
- 2026-05-01 — [knowledge] Five `AttributeData` resources + attribute value/upgrade API (flat $1000/level)
- 2026-05-01 — [knowledge] `PerkData` + perk unlock/has/get API with attribute-threshold gating
- 2026-05-01 — [knowledge] `KnowledgeAction` enum: `INSPECT`, `REVEAL`, `APPRAISE`, `REPAIR`, `SELL`, `RESTORE`
- 2026-05-01 — [knowledge] Knowledge Hub scene + Mastery / Attributes / Perk sub-panels
- 2026-05-01 — [knowledge] `KnowledgeManager.validate()` registered with `RegistryCoordinator`; boot-time audit of registries + unlocked perk ids
- 2026-05-01 — [knowledge] Skill system fully removed; SPECIAL-style attributes replace it

## Vehicle

- 2026-05-01 — [vehicle] `CarData` resource: `car_id`, `display_name`, `grid_columns`, `grid_rows`, `max_weight`, `stamina_cap`, `fuel_cost_per_day`, `extra_slot_count`
- 2026-05-01 — [vehicle] `CarData` consumed by `RunRecord` (stamina, fuel, trailer slots) and cargo scene (grid, weight, trailer slots)
- 2026-05-01 — [vehicle] `SaveManager.active_car` via `CarRegistry`; active car getter
- 2026-05-01 — [vehicle] CarData added to YAML-to-tres pipeline + 4 `.tres` files with distinct progression
- 2026-05-01 — [vehicle] Car select scene with stat preview; sets `active_car_id`
- 2026-05-01 — [vehicle] `CarData.price` and `CarData.icon` fields; `stats_line()` helper shared by CarCard and CarRow
- 2026-05-01 — [vehicle] `SaveManager.owned_cars` persistence; append on purchase; migration for starter car
- 2026-05-01 — [vehicle] `MetaManager.buy_car()` (debit, append, save); `MetaManager.set_active_car()` (swap active)
- 2026-05-01 — [vehicle] Car shop scene: browse purchasable cars, buy with cash
- 2026-05-01 — [vehicle] Vehicle hub navigation menu (Garage / Car Shop / Back)
- 2026-05-01 — [vehicle] `CarRow` component: `setup()`/`_apply()` pattern; in-place active-car swap without row rebuild
- 2026-05-01 — [vehicle] `CarCard` component: `setup()`/`_apply()` pattern; Buy button with affordability gating
- 2026-05-01 — [vehicle] Hub: `VanButton` → `VehicleButton`; `VanPopup` removed; wired to `GameManager.go_to_vehicle_hub()`

## Item Display

- 2026-05-01 — [display] `ItemViewContext` removed; components take `ItemEntry` directly; no stage enum, no per-stage branching, no merchant/order side-channels
- 2026-05-01 — [display] `ItemRow` / `ItemListPanel` read every field through `ItemEntry` getters
- 2026-05-01 — [display] `ItemRow` column set reduced to display columns only; transaction columns removed with merchant channel
- 2026-05-01 — [display] `ItemListPanel`: reusable sortable table; runtime-built headers; per-row selection state
- 2026-05-01 — [display] Column order matches columns array passed at `setup()`
- 2026-05-01 — [display] `ItemCard`: clue-aware inspection card; veiled items hide derived fields and show `"???"`
