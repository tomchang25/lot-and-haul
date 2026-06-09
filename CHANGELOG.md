# Changelog

Append-only record of shipped work. This is the project's permanent "done" history.

**Why this file exists:** it is the single home for "what got built." Because it is append-only — you only ever add entries, never reconcile them against current code — it cannot go stale. This is what lets every other tracking surface stay forward-only: `systems/` describes the system as it _is_ (present tense, no Done lists) and `TODO.md` holds only open work (`## Active` in-flight flows, `Plan`/`Chore`/`Bug`, and `## Draft` concepts), with multi-step flows detailed in `dev/docs/plans/` files. When a phase ships, append one entry here, then cut that phase from its plan file; when a whole flow ships, also delete its `TODO.md` line.

This file is the single source of truth for the entry format. Each entry: `- YYYY-MM-DD — [scope] one-line summary (commit/PR ref)`. Group related entries under a `## <Title>` heading — title only, no "Phase"/"Stage" wording.

---

## Unified Debug System

- 2026-06-09 — [debug] `Debug` autoload added (`global/autoloads/debug.gd`): unified gate combining `OS.is_debug_build()` (build-time) and `SettingsStore.debug_mode` (user preference); exposes `enabled` property, `toggled` signal, and `set_debug_mode()` mutator
- 2026-06-09 — [debug] `SettingsStore.debug_mode` wired with setter + `debug_mode_changed` signal so any write (via `Debug.set_debug_mode()` or direct assignment) is runtime-correct
- 2026-06-09 — [debug] Auction scene debug overlay (`auction_scene.gd`) migrated from `OS.is_debug_build()` to `Debug.enabled`; connects `Debug.toggled` for reactive show/hide
- 2026-06-09 — [debug] Settings Overlay checkbox routes through `Debug.set_debug_mode()` instead of writing `SettingsStore.debug_mode` directly
- 2026-06-09 — [standards] `dev/standards/debug_standard.md` added: documents the two-layer debug gate, `Debug` autoload API, coding patterns (one-shot init, reactive toggle, conditional logic), node-source rules, and release safety
- 2026-06-09 — [standards] `block_scene_architecture_standard.md` updated: debug node references changed from `OS.is_debug_build()` to `Debug.enabled`
- 2026-06-09 — [docs] CLAUDE.md updated with Debug autoload in load order and debug standard pointer in Standards section

---

## Centralized Theme

- 2026-06-09 — [theme] `main_theme.tres` populated with centralized design tokens: color palette (primary/hover/pressed/disabled text), default font size 16, Button StyleBoxes (5 states), PanelContainer panel, TooltipPanel, HSeparator/VSeparator, container separation defaults (HBox/VBox=8, Grid=6×6)
- 2026-06-09 — [theme] Custom CheckBox icons added (`global/theme/icons/`): bright-border checked/unchecked/disabled PNGs visible on dark backgrounds; CheckBox theme entries with transparent StyleBoxEmpty background
- 2026-06-09 — [theme] Project-level theme set via `project.godot → [gui] theme/custom`; all scenes inherit automatically
- 2026-06-09 — [theme] Removed stale `NormalFont.ttf` ext_resource reference (font file was already deleted)
- 2026-06-09 — [standards] `dev/standards/theme_standard.md` added: documents palette, typography scale, spacing defaults, semantic gameplay colors, override rules, and incremental migration approach
- 2026-06-09 — [docs] CLAUDE.md updated with theme standard pointer in Standards section

---

## Start Page & Settings Overlay

- 2026-06-09 — [start_settings] `SettingsStore` autoload added (`global/autoloads/settings_store.gd`): persists master/sfx/music volume, fullscreen, debug_mode to `user://settings.json`; applies audio bus volumes and display mode on boot; toggles settings overlay on `ui_settings` input (Escape)
- 2026-06-09 — [start_settings] `SettingsOverlay` component added (`game/shared/settings_overlay/`): modal CanvasLayer (layer=100, PROCESS_MODE_ALWAYS) with Audio (Master/SFX/Music sliders), Display (fullscreen), and Gameplay (debug mode) sections; pauses tree on open, unpauses on close via `closed` signal
- 2026-06-09 — [start_settings] `StartPageScene` added (`game/meta/start/`): boots as `main_scene`; shows "New Game" or "Continue" based on save-file presence; routes to hub, settings overlay, or quit
- 2026-06-09 — [start_settings] `default_bus_layout.tres` added with Master/SFX/Music/UI buses; registered in `project.godot` under `[audio]`; `SceneRegistry.start_page` wired in `scene_router.tscn`
- 2026-06-09 — [standards] Block scene architecture standard updated: `%UniqueName` preferred over `$path` for node references in new/edited scenes; `$path` legacy-allowed in untouched code; `unique_name_in_owner = true` must be a property line, not a header attribute
- 2026-06-09 — [skills] `dev/skills/godot4_tscn_node_properties.md` added: exhaustive list of valid `.tscn` node header attributes (`name`, `type`, `parent`, `instance`, `unique_id`) vs. property lines; `unique_name_in_owner` worked example

---

## Save & Managers Refactor

- 2026-06-06 — [refactor] SaveManager stripped to a thin persistence coordinator (81 lines, no gameplay state); gameplay state distributed to 10 Store archetypes under `common/gameplay/store/` — 8 persisting (EconomyStore, GarageStore, StorageStore, SlotStore, ProgressStore, CustomersStore, KnowledgeStore) and 2 session-scoped (RunStore, LotStore) — all extending `StoreBase` with `section_id/to_dict/from_dict/_store_version/_apply_migrations`; Managers (MetaManager, KnowledgeManager) register as providers and coordinate cross-domain transactions; RunManager owns RunStore + LotStore factories and run-phase mutations
- 2026-06-06 — [refactor] Meta↔Knowledge dependency cycle broken via EventBus signals (`sale_resolved`, `item_repaired`, `item_restored`, `run_resolved`); MetaManager emits post-commit, KnowledgeManager subscribes for XP accrual; `upgrade_attribute` transaction moved to MetaManager
- 2026-06-06 — [refactor] RunRecord decomposed into RunStore (per-run cumulative state) + LotStore (per-lot mutable state: lot_entry, actions_remaining, won_items); RunManager owns AP deficit-refill handoff at lot boundaries; `RunResult` Snapshot added for run-end economics handoff
- 2026-06-06 — [refactor] All Stores use private backing vars + getter-only properties (language-enforced read-only); collection getters return `.duplicate()`; 35+ proxy properties removed from managers; scenes access state via `MetaManager.economy.cash`, `RunManager.lot.actions_remaining`, etc.
- 2026-06-06 — [refactor] Per-store versioned migrations replace top-level `run_migrations()`; legacy flat-save fallback and schema 1→2 migration removed; `RegistryCoordinator` removed; `ResourceRegistry` base class added for all registries
- 2026-06-06 — [refactor] `autoload/` → `autoloads/` folder rename; runtime types organized into archetype subfolders (`instance/`, `store/`, `snapshot/`, `service/`); `Customer` → `CustomerEntry`; `location_select` / `location_entry` → `*_scene` suffix
- 2026-06-06 — [docs] Systems docs L2 audit; `data_architecture.md` vision added; naming conventions updated for singular archetype folders; `DaySummary` reclassified as Snapshot

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
