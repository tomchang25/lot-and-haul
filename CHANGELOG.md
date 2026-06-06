# Changelog

Append-only record of shipped work. This is the project's permanent "done" history.

**Why this file exists:** it is the single home for "what got built." Because it is append-only — you only ever add entries, never reconcile them against current code — it cannot go stale. This is what lets every other tracking surface stay forward-only: `systems/` describes the system as it _is_ (present tense, no Done lists) and `TODO.md` holds only open work (`## Active` in-flight flows, `Plan`/`Chore`/`Bug`, and `## Draft` concepts), with multi-step flows detailed in `dev/docs/plans/` files. When a phase ships, append one entry here, then cut that phase from its plan file; when a whole flow ships, also delete its `TODO.md` line.

This file is the single source of truth for the entry format. Each entry: `- YYYY-MM-DD — [scope] one-line summary (commit/PR ref)`. Group related entries under a `## <Title>` heading — title only, no "Phase"/"Stage" wording.

---

## Manager Decoupling & Store Exposure

- 2026-06-06 — [refactor] Phase 1: `upgrade_attribute` transaction moved from KnowledgeManager into MetaManager; three EventBus signals added (`sale_resolved`, `item_repaired`, `item_restored`); MetaManager emits post-commit, KnowledgeManager subscribes for XP; `ResearchSlot` stripped of all autoload references; Meta↔Knowledge dependency cycle fully broken
- 2026-06-06 — [refactor] Phase 2: `RunResult` Snapshot added (`common/gameplay/snapshot/`); `RunManager.take_run_result()` auto-reveals surface clues and snapshots economics before handoff; `MetaManager.resolve_current_run` consumes `RunResult` instead of touching `_run_store` directly; `RunManager._run_store` is now truly private; `run_resolved` signal added to EventBus
- 2026-06-06 — [refactor] Phase 3: all 7 Stores converted to private backing vars + getter-only properties (language-enforced read-only externally); collection getters return `.duplicate()` for iteration stability; 35+ proxy properties deleted from MetaManager and RunManager; store references exposed as plain public fields (`economy`, `garage`, `storage`, `slot`, `progress`, `customers`, `run`); ~20 scene files updated to store-direct access (`MetaManager.economy.cash` etc.); new RunStore mutation methods (`initialize`, `deduct_ap`, `record_lot_win`, `init_browse`, `advance_browse_index`, `set_cargo_result`); new SlotStore mutators (`set_storage_ap`, `set_selling_slots_today`); `ONSITE_SELL_PRICE` moved to `Economy` constants

---

## StoreBase Extraction + RunRecord Decomposition

- 2026-06-06 — [refactor] Introduced `StoreBase extends RefCounted` as the shared base for all Store archetypes; all 7 persisting Stores and the new `RunStore` extend it; empty `migrate()`/`validate()` overrides removed from Stores where StoreBase no-ops suffice
- 2026-06-06 — [refactor] Renamed `RunRecord` → `RunStore` (moved to `common/gameplay/store/`); stripped factory + AP resolution logic out of the class; `RunManager` now owns `create_run_store()`, `_resolve_inspection_ap_cap()`, `_resolve_refill_reserve()`, `_compute_travel_costs()`; `set_lot()` and all state fields remain on `RunStore`; `run_record` accessor renamed to `run_store` across all run-phase scenes
- 2026-06-06 — [refactor] Reclassified `DaySummary` → `DaySnapshot` (moved to `common/gameplay/snapshot/`); updated `MetaManager.end_day()` return type, `SceneRouter` pending field, and `DaySummaryScene` type annotation; scene/route/packed-scene names unchanged
- 2026-06-06 — [refactor] Renamed `DaySnapshot` → `DaySummary` (file: `day_snapshot.gd` → `day_summary.gd`, class: `DaySnapshotScene` → `DaySummaryScene`); updated all callers in `MetaManager.end_day()`, `SceneRouter`, and `DaySummaryScene` type annotations

---

## SaveManager Provider Unification & Legacy Cleanup

- 2026-06-06 — [refactor] Merged `_sections` + `_managers` into single `_providers` array in SaveManager; replaced `register_section`, `register_sections`, and `register_manager` with single `register_provider` (asserts all four StoreBase methods); MetaManager and KnowledgeManager each call `register_provider(self)` once; all four iteration sites (`save`, `load`, `run_migrations`, `run_validation`) updated to `_providers`
- 2026-06-06 — [refactor] Per-store versioned migrations: added `_store_version()` and `_apply_migrations()` to StoreBase; removed `migrate()` from StoreBase, GarageStore, KnowledgeStore, MetaManager, KnowledgeManager, and SaveManager; removed `run_migrations()` from SaveManager and boot call in GameManager; all 6 persisting stores write `_version` in `to_dict()` and read it in `from_dict()`; removed `erase_points()`/`erase_category_points()` dead code; removed `skill_levels` legacy branch from KnowledgeStore
- 2026-06-06 — [refactor] Removed unreachable legacy paths from SaveManager.load(): flat-save fallback and schema 1→2 migration branch; load() now requires "sections" key (push_error otherwise); removed stale comment about removed systems; removed `research_slots` migration check and `_migrate_research_slots()` from StorageStore (pre-time-slot saves are gone); updated docstrings in both files

---

## LotStore Extraction

- 2026-06-06 — [refactor] Extracted per-lot state from RunStore into new session-scoped LotStore (`common/gameplay/store/lot_store.gd`): owns `lot_entry`, `actions_remaining`, `won_items`, `won_price` with per-lot lifecycle; RunStore retains only per-run cumulative and configuration state; RunStore gains `draw_ap_from_reserve()` and `accumulate_lot_result()`; RunManager gains `var lot: LotStore`, updated `set_lot()` with deficit-refill AP handoff, `clear_lot()`, and updated `spend_ap()`/`commit_lot_win()`/`clear_run_state()`; all scenes migrated from `RunManager.run.lot_*` to `RunManager.lot.*`; `_last_lot_won_items` eliminated

---

## Systems Docs L2 Audit

- 2026-06-05 — [docs] Audited all 10 systems/ docs against the L2 exclusion rule; lifted the two-layer (designer resource / runtime type) concept to new vision/data_architecture.md; dropped Reads/Writes/Ownership/roster tables to L3 (enriched item_card.gd docstring); trimmed hub_home/knowledge/vehicle/customer_sell/autoloads/item_display/item_system to cross-flow only; archived data_model.md (concept now in vision, field detail in code)

## Meta Domain Decomposition

- 2026-06-02 — [meta] MetaManager decomposed into six domain owners (EconomyOwner, GarageOwner, StorageOwner, SlotOwner, ProgressOwner, CustomersOwner) under global/autoload/meta_manager/; each owns its fields and save payload with sanitize-on-load warnings for unresolved ids; MetaManager exposes transparent proxy properties (GDScript 4 get/set) so all scenes and autoloads need no changes; CarRegistry and LocationRegistry validate() stripped of live-state reads; ItemEntry.from_dict push_error softened to push_warning; six SaveSection adapter files retired to tombstubs
- 2026-06-02 — [meta] MetaManager owner refactor: behavior moved into each domain owner (EconomyOwner: can_afford/spend/earn/apply_delta; GarageOwner: owns_car/add_car/set_active; StorageOwner: register_entry/register_entries/remove_entries; SlotOwner: set_slot/charge_ap/stash_pending_run/clear_pending_run; ProgressOwner: advance_day/set_locations/clear_locations; CustomersOwner: record_sale/remove_customer/clear_sales/set_customers); proxy setters removed (getter-only, reference collections return shallow duplicate); resolve_run double-save eliminated (single SaveManager.save() at commit); KnowledgeManager.upgrade_attribute routed through MetaManager.spend_cash() instead of direct field write

## Save Section via Manager

- 2026-06-05 — [save] SaveManager section providers changed from 7 individual Stores to 2 Managers (MetaManager, KnowledgeManager); each Manager implements to_dict/from_dict/migrate/validate and fans out to its Stores; save() now merges each provider's flat multi-key dict; load() passes the full sections dict to each provider (Manager self-selects its keys); all 7 Stores gain no-op migrate()/validate() hooks; on-disk format and key layout unchanged

## Save State Ownership Refactor

- 2026-06-02 — [save] SaveManager becomes a thin coordinator (file IO, schema, dispatch only; no gameplay state fields); KnowledgeManager owns category_points/attribute_levels/unlocked_perks and provides the "knowledge" save section; MetaManager owns all remaining meta-progression state (cash, garage, storage, slot, progress, customers) and registers six inner section providers; schema bumped to 2 with load-time migration that relocates knowledge keys out of the economy section; section .gd files replaced with tombstone stubs; all SaveManager.<field> references removed outside the persistence layer

## Template Spine Backport

- 2026-06-01 — [registry] Added `ResourceRegistry` base class; ItemRegistry/CarRegistry/ClueRegistry/CategoryRegistry/LocationRegistry/SuperCategoryRegistry now extend it (override `_dir_path`/`_id_of`), dropping duplicated `_ready`/`size`/`_by_id` boilerplate while keeping per-registry `migrate`/`validate` and typed wrappers
- 2026-06-01 — [save] SaveManager refactored to section-based dispatch: state fields stay on SaveManager (call sites unchanged), serialization delegated to economy/garage/storage/progress/slot/customers sections via `register_section`/`to_dict`/`from_dict`; new on-disk format `{schema_version, sections}` with backward-compatible read of legacy flat saves; legacy `research_slots`/`skill_levels` migrations moved into the storage/economy sections

## Customer Sell UX Polish

- 2026-06-01 — [customer-sell] Fixed grid rotation pivot drift: `_grab_index` pins the grabbed cell under the cursor across Q/E rotations; list picks anchor to shape centroid
- 2026-06-01 — [customer-sell] Bidirectional list↔grid hover sync via `set_external_hover_item()`; hover state re-emitted after place/cancel to clear stale highlights
- 2026-06-01 — [customer-sell] Back to Hub button moved to bottom FooterRow; CustomerTabsRow wrapped in ScrollContainer to handle overflow with many customers
- 2026-06-01 — [customer-sell] `CURSOR_DRAG` feedback while holding an item; `queue_redraw()` in `_apply_state_style` for immediate row colour updates

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
