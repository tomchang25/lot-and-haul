# Changelog

Append-only record of shipped work.

Rules:

- Add shipped work only; do not keep forward-looking items or Done lists here.
- Each entry uses `- YYYY-MM-DD — [scope] one-line summary`.
- `##` headings are version headings only. Entries must live under `###` section headings; only version notes may sit directly under a `##` heading.
- `###` headings group related entries. Section titles are plain names, not "Phase"/"Stage" labels.
- Keep entries concise and outcome-focused. Avoid hype, speculative performance claims, and implementation mechanics unless needed to identify the fix.
- When a phase ships, append the entry here and cut the shipped work from its plan/TODO source.
- Do not add entries for dev-process-only maintenance, including closeout workflow changes, CHANGELOG/TODO edits, plan archival, or tracking cleanup.

## v0.1.3 - Draft

## v0.1.2

### Customer Generation

- 2026-06-16 — [customer_grid] Customer generation now samples demand from affix combinations scoped to one selected category and sizes each customer grid to fit that category's largest anchor shape
- 2026-06-16 — [customer_sell] Nightly customer generation now applies a bounded match floor so open shop usually includes actionable buyers when stored items expose fit tags

### Standards

- 2026-06-15 — [standards] `scene_node_source_standard.md` added as the canonical source for persistent `.tscn` nodes, permitted runtime node creation, and `node-src` markers; scene architecture docs now point to it

### Plain-Item Baseline Removal

- 2026-06-16 — [refactor] Removed legacy plain-item baseline from ItemGenerator: `surface_min`/`surface_max` params, `_draw_surface_clues()` function, `Economy.SURFACE_CLUE_MIN/MAX` constants, and `ClueData.domain` field; all callers updated to new 3-param `draw()` signature
- 2026-06-16 — [refactor] Added `test_affix`/`test_comb` YAML fixtures so tests exercise the affix→combination→clues pipeline instead of the removed baseline

### Inspection Detail & Summary Popup

- 2026-06-15 — [inspection] Inspection restructured into select-then-act model: card click selects without spending AP; unveil/inspect actions moved to right-side detail rail with explicit action buttons; aggregate found/veiled/estimate lists removed from right rail
- 2026-06-15 — [inspection] Pre-auction summary popup added with ItemBrowserPanel (Card/Table modes), total value estimate, and opening bid display; forward button opens modal instead of routing directly to auction

### Item Card Refinements

- 2026-06-15 — [ui] Shared ClueChunk component (spoiler-safe clue block) + reshaped ItemCard + ItemBrowserPanel (Card/Table modes) + ItemCardPopup; Storage and Inspection use the shared browser; legacy ItemRowTooltip replaced with ItemCardPopup across cargo, reveal, and run_review scenes
- 2026-06-15 — [ui] Persistent tooltip popups moved into .tscn (ItemCardPopup); node-reference style fixed across cargo, reveal, and run_review scenes
- 2026-06-15 — [ui] ClueChunk/ItemBrowserPanel child reuse patterns fixed; cross-mode selection behavior corrected

### Run Settlement & Cargo Panel

- 2026-06-15 — [run-review] `CargoManifestPanel` added: collapsible cargo list with expand/collapse toggle, damage-count display, and tooltip relay for ItemCardPopup
- 2026-06-15 — [run-review] Settlement view redesigned: itemized finance ledger (Entry Fee, Fuel w/ travel-day multiplier, Auction Purchases, On-site) replaces aggregated "Cost Cash"; location subtitle added; layout restructured with scroll container, header panel, and settlement card

### Cargo UI Stability & Theme Cleanup

- 2026-06-15 — [fix] Scene transitions are deferred and PackingGrid input is guarded so events do not target scenes after removal
- 2026-06-15 — [fix] ClueChunk detaches surplus children before `queue_free()`, preventing freezes when clue row counts shrink
- 2026-06-15 — [perf] Cargo packing hover UI reuses StyleBoxFlat resources and clears only the previous highlighted row
- 2026-06-15 — [theme] Cargo packing styles moved into `main_theme.tres`; `ThemeColors` added for shared semantic colours

## v0.1.1

### Maintenance

- 2026-06-14 — [fix] New game reset now assigns the "van_basic" starter car to the garage; `_assign_starter_car()` called during `MetaManager.reset()`
- 2026-06-14 — [theme] Checkbox icon resource UIDs updated in `main_theme.tres`
- 2026-06-14 — [config] Default window size reduced from 1920×1080 to 1280×720 in `project.godot`

## v0.1.0

First public alpha, released on itch.io as a free playtest. The core storage-lot loop is fully playable: location selection → inspection → auction bidding → cargo packing → storage research → customer selling → upgrades. Built in Godot 4.6. This is an intentionally early build — placeholder/AI-assisted visuals, provisional balance, incomplete onboarding, limited content density. The defining mechanic is **information asymmetry**: appraised value is your best guess from surface clues; verified value is the truth revealed through storage authentication. The gap between the two drives every auction bid and every sell-or-keep decision.

### Robustness Hardening

- 2026-06-14 — [ci] `dev/ci/error_filters.json` added as canonical error-filter source of truth; `test_error_filters_consistency.gd` asserts GDScript constants match the JSON
- 2026-06-14 — [ci] CI pilot scene wiring verification enters scenes for 2 frames to exercise `_ready()` paths; mid-flow invariants added for cash, storage, lot-active, and step-finality checks
- 2026-06-14 — [test] Director unit coverage: accessor lifecycle, missing anchor auto-skip, offer acceptance signal, unknown-script fallback, tutorial-seen tracking
- 2026-06-14 — [harness] TestbedPilot stall detection retries once before declaring a stall, reducing false positives from single slow frames
- 2026-06-14 — [ci] CI grep filter updated with `[DEBUG-PASS]` marker to exempt intentional programmer-error guard tests from error detection
- 2026-06-14 — [tutorial] `_end_tutorial()` marks the completed script as seen via `MetaManager` before clearing playback state
- 2026-06-14 — [fix] Unused-parameter warning cleanups: `_origin`, `_action_type`, `_rotation` renames across cargo, inspection, and packing_grid scenes
- 2026-06-14 — [test] Regression test cleanup fixed enum-typed clue fixtures, baseline item condition, YAML-backed run clue draw bounds, and migration test formatting after the Phase 2 robustness test-data pass
- 2026-06-14 — [dev] Godot headless/test guidance now warns that `/tmp` must be container-native Linux storage; a new cross-OS mount hazard card documents the Docker bind-mount failure mode

### Web Export Build Flow

- 2026-06-13 — [export] Web export preset added with `all_resources` packaging and `build/web/index.html` output for local and itch.io browser builds
- 2026-06-13 — [dev] VS Code task added to serve the Web export from `build/web` at `localhost:8000`
- 2026-06-13 — [fix] Resource directory loading now accepts exported `.tres.remap` entries so registry autoloads load designer resources from Web `.pck` builds

### Affix Generation System

- 2026-06-13 — [feat] AffixData/AffixCombinationData designer resources with YAML pipeline, cross-product conflict validator, and AffixRegistry autoload
- 2026-06-13 — [feat] Reversed ItemGenerator.draw(): affix → combination → clues; \_draw_affixes/\_pick_combination added; rarity-draw path retired for affixed items
- 2026-06-13 — [feat] category_scope converted to resource-ref array; generic (empty-scope) affix support
- 2026-06-13 — [feat] ItemEntry gains affixes/combination_ids with save/load round-trip and backward-compat defaults
- 2026-06-13 — [feat] Affix-only naming: display_name() composes from affix display_names + anchor body; naming_slot/naming_priority removed from ClueData/AnchorData and pipeline
- 2026-06-13 — [data] 5–8 playtest affixes authored in data/yaml/affixes.yaml with 2–3 combinations each

### ItemGenerator Factory Collapse

- 2026-06-13 — [refactor] ItemGenerator.draw() returns ItemEntry directly; GenerationResult and ItemEntry.from_generation() deleted
- 2026-06-13 — [test] Test data authored as YAML (\_test_item_generator.yaml); in-memory stub helpers removed
- 2026-06-13 — [refactor] storage_fixtures.gd migrated to ItemGenerator.draw() with seeded RNG
- 2026-06-13 — [doc] dev/standards/test_data.md created for test-data-as-YAML workflow

### Scene Testbeds & Agent Harness

- 2026-06-13 — [dev] SaveManager test slot isolation: `use_test_slot()` wipes and redirects to a non-numeric test slot; boot-load and slot-listing skip it so no normal boot ever resumes into test data
- 2026-06-13 — [dev] `TestbedRegistry` (`stage/testbeds/testbed_registry.gd`) with `static var REGISTRY` and shared `launch()` entry point consumed by both the manual launcher and the agent pilot
- 2026-06-13 — [dev] Scene fixtures for 3 flows: storage/workshop (reusing `StorageFixtures`), location-entry→run-start (`LocationEntryFixtures`), and nightly selling (`CustomerSellFixtures`)
- 2026-06-13 — [dev] `TestbedLauncher` scene (debug-gated, one button per registry entry) + start-page debug entry point for manual interactive use
- 2026-06-13 — [dev] `TestbedPilot` autoload (`global/autoloads/harness/testbed_pilot.gd`) — `--testbed=<id>` CLI flag launches the same wipe-seed-enter sequence headlessly, drives the flow, and captures per-step screenshots
- 2026-06-13 — [dev] `TestbedChecks` static class (`testbed_checks.gd`) with log-scan (error-level lines w/ benign-noise filter), stall detection (per-step timeout bound), and foreground-panel overlap checks
- 2026-06-13 — [doc] `dev/agent_rules/godot_screenshot_check.md` updated with testbed pilot reference and headless run command
- 2026-06-13 — [skill] `dev/skills/gdscript_const_vs_static_var.md` documents the `const` vs `static var` pitfall for manifest/registry arrays under clean headless import
- 2026-06-13 — [doc] `dev/docs/plans/scene_testbeds_and_agent_harness.sketch.md` shipped and archived

### Director Split & Testing Taxonomy

- 2026-06-13 — [refactor] Director autoload split into two focused autoloads: Director (presentation: dim overlay, hint/popup panels, step playback, Anchor registration, Help button) and ScriptDirector (orchestration: scene registration callbacks, auto-start/offer/help decisions, injection skeleton, phase lifecycle)
- 2026-06-13 — [refactor] Scene registration emits `register_scene_callback` signal instead of branching internally; hub and storage scenes unchanged — still call `Director.register_scene()`
- 2026-06-13 — [refactor] ScriptDirector connects to Director signals and drives tutorial start/offer/help decisions from game state (seen flags), leaving Director presentation-only
- 2026-06-13 — [dev] Testing taxonomy documented in `project_structure.md`: three verification layers (unit tests in `test/`, testbeds in `stage/testbeds/`, harnesses in `global/autoloads/harness/`) with placement rules and triage principle
- 2026-06-13 — [doc] `dev/docs/plans/director_split_and_testing_taxonomy.sketch.md` shipped and archived

### Test Harness Consolidation

- 2026-06-13 — [dev] Relocated `ShotPilot` and `CIPilot` from top-level autoload dirs into `global/autoloads/harness/`; updated `project.godot` autoload paths and `game_manager.gd` comment
- 2026-06-13 — [dev] Director seam: extracted public `advance_step()` / `accept_offer()` commands; routed `_on_hint_next_pressed`, `_on_popup_next_pressed`, and `_on_offer_start_pressed` through them; removed `debug_*` twin methods (`debug_advance_step`, `debug_accept_offer`); renamed read accessors (`debug_step_index` → `step_index`, etc.)
- 2026-06-13 — [dev] Generic-pilot PoC: ShotPilot now manifest-driven (`MANIFEST` constant table); `_seed_storage_state` + `_sample_clues` moved to `game/meta/storage/storage_fixtures.gd`; fixture lookup via path convention; `_enter_scene` replaces per-script match dispatch
- 2026-06-13 — [dev] Updated `godot_screenshot_check.md` with triage note (prefer unit assertion over screenshot) and manifest-plus-fixture flow for new targets

### Tutorial Screenshot Harness — ShotPilot

- 2026-06-13 — [tutorial] `ShotPilot` autoload (`global/autoloads/shot_pilot/shot_pilot.gd`): flag-gated (`--tutorial-shot=<id|all>`) capture harness that seeds game state, navigates to the owning scene, accepts the offer prompt, advances through every tutorial step, and saves one PNG per step to a configurable output directory (`--shot-dir=<path>`, default `user://tutorial_shots`); exits 0 on success, 1 on unknown script id
- 2026-06-13 — [tutorial] Director debug surface: `debug_step_index()`, `debug_step_count()`, `debug_step_anchor_id(i)`, `debug_is_offer_showing()`, `debug_advance_step()`, `debug_accept_offer()` — enables programmatic capture without input simulation
- 2026-06-13 — [tutorial] Storage state seeding: `ShotPilot._seed_storage_state()` creates 3 `ItemEntry` instances from registry data, marks first as repair-complete (condition = 0.5), registers via `MetaManager.register_storage_items()`, and begins a storage slot with full AP pool; row selection via `ItemListPanel.row_pressed` signal
- 2026-06-13 — [tutorial] `dev/docs/plans/tutorial_shot_harness.sketch.md` shipped and archived

### Tutorial Hint Panel — Director System

- 2026-06-12 — [tutorial] `Director` autoload added: code-built dim-overlay CanvasLayer (layer 120) with hint/popup step display, four-rect hole cutout, per-frame anchor tracking, and help button; registered in `project.godot` after SceneRouter
- 2026-06-12 — [tutorial] `TutorialStep` RefCounted resource class with Kind (HINT/POPUP), Advance (NEXT/SCENE_ENTERED), unlock_anchor flag
- 2026-06-12 — [tutorial] `TutorialScripts` static class with hub script (slot intro → activity popup → Storage button unlock) and storage script (welcome popup → item table → detail rail → repair/restore/research → appraised-vs-verified popup → AP label → leave button)
- 2026-06-12 — [tutorial] Hub scene integration: `Director.register_scene("hub", ...)` with slot_label and storage_btn anchors; auto-starts on first visit
- 2026-06-12 — [tutorial] Storage scene integration: `Director.register_scene("storage", ...)` with 7 anchors; first-visit offer prompt (start/skip), Help button replay; all steps explain-only
- 2026-06-12 — [tutorial] ProgressStore schema v2: `tutorial_seen` dictionary with migration branch; `MetaManager.mark_tutorial_seen()` wired to deferred save
- 2026-06-12 — [test] `ItemEntry.attempt_clue()` gains optional `rng` parameter; test RNG injection for deterministic clue roll assertions

### CI Headless Run-Loop Test Suite

- 2026-06-12 — [ci] RNG injection refactor: `ItemEntry`, `LotEntry`, `ItemGenerator` gain optional seedable RNG parameter with null-fallback preserving all production call sites; `RandomUtils` extended
- 2026-06-12 — [ci] GUT plugin installed + Layer 1 manager unit tests: AP lifecycle, clue hit/miss, cargo commit, trailer damage, full scratch-to-hub traversal; test-flag boot gate skips save loading and scene routing
- 2026-06-12 — [ci] CI pilot autoload (`CIPilot`) auto-pilots one full run headless with force-win hook; Layer 2 smoke test via log grep with known-benign allowlist
- 2026-06-12 — [ci] GitHub Actions workflow (`ci.yml`): parallel unit test + smoke test jobs, Godot binary caching, YAML pipeline prereq, 5-minute timeout
- 2026-06-12 — [docs] `dev/docs/plans/ci_run_loop_tests.md` shipped and archived

---

### Placeholder SFX Pipeline

- 2026-06-12 — [sfx] Deterministic synth pipeline (`render_sfx.py` + `sfx_synth.py`): YAML → WAV + `UiAudioEvent` `.tres` rendering with seed-based determinism, QC pass (peak-normalize, fade-out, length cap), variant support, and idempotent re-run
- 2026-06-12 — [sfx] Standard interaction sound set authored (12 YAML files under `data/yaml/sfx/`): click, bid_confirm, auction_won, auction_lost, reveal_good, reveal_bad, sale_completed, cash_credited, blocked_error, confirm, cancel_dismiss, button_hover
- 2026-06-12 — [sfx] SFX generation prompt (`dev/tools/prompts/yaml_generation/sfx.md`) with full schema, real-unit field definitions, intent→sound convention mapping table
- 2026-06-12 — [sfx] `SfxButton` component (`game/shared/sfx_button/`): Button subclass with default press/hover audio events, per-button override/mute via inspector exports, hover spam rate-limiting; migrated across all game scenes (~45 buttons)
- 2026-06-12 — [sfx] Semantic sound call sites across 8 game scenes: auction (bid_confirm, auction_won), inspection (reveal_good/reveal_bad, blocked_error), reveal (reveal_good, auction_lost), cargo (blocked_error, grid placement sounds), customer_sell (sale_completed, cash_credited, confirm/cancel, grid lift/put-down), day_summary (cash_credited), run_review (cash_credited)
- 2026-06-12 — [sfx] `scene_changed` signal added to `SceneRouter` for scene-transition hooks
- 2026-06-12 — [sfx] UI bus default lowered to −8 dB for quieter overall HUD loudness

### Error Guard System

- 2026-06-12 — [toast] `ToastManager.show_error()` always-visible red error channel added (8 s duration) for runtime error fallback alerts
- 2026-06-12 — [toast] `ToastManager.show_dev_error()` one-call programmer-error guard added: always logs `push_error("[DEV] " + msg)`, shows red toast only when `Debug.enabled`, session fire-once dedupe
- 2026-06-12 — [standard] `dev/standards/error_guard_standard.md` created: three-category guard system (runtime guard, programmer error, precondition guard) replacing `assert()` with explicit `if` + ToastManager channel; §3a bans bare `push_error` at call sites (exceptions: `toast_manager.gd` itself, boot-phase code with `# push-error: boot` marker)
- 2026-06-12 — [lint] `lint_standards.py` gains bare-push-error check across all project GDScript dirs (`game`, `stage`, `common`, `global`, `data`); check dispatch restructured into `GD_SCENE_CHECKS` / `GD_ERROR_GUARD_CHECKS` scopes; match-wildcard safe-set updated from `push_error` to `ToastManager.show_dev_error`
- 2026-06-12 — [standard] `standards_enforcement.md` documents bare push_error ban as active check; `naming_conventions.md` match-wildcard reference updated to `show_dev_error`
- 2026-06-12 — [docs] CLAUDE.md updated: Notifications section adds `show_error`/`show_dev_error` mentions, Error guards section added with standard pointer
- 2026-06-12 — [error_guard] 17 files migrated from `assert()` / bare `push_error` to typed guards: `auction_scene.gd`, `inspection_scene.gd`, `location_entry_scene.gd` (2×), `reveal_scene.gd` (runtime — `show_error` + navigate); `state.gd`, `state_machine.gd` (2×), `cargo_shapes.gd`, `economy_store.gd` (2×), `audio_manager.gd`, `knowledge_manager.gd` (3×), `meta_manager.gd`, `run_manager.gd`, `resource_registry.gd`, `super_category_registry.gd`, `resource_dir_loader.gd`, `save_manager.gd` (7× — 5 precondition + 3 runtime I/O), `registry_audit.gd` (programmer error — `show_dev_error` + return/sentinel); `settings_store.gd` (4×) annotated with boot markers

### Location Selection Cost Preview

- 2026-06-11 — [location] Fuel cost line item (`fuel_cost_per_day × travel_days`) surfaced in `LocationCard` scene between lot count and estimated total

### Save Slots & Start Page New Game

- 2026-06-11 — [save] Three independent save slots (`user://save_slots/slot_N/`): each slot has its own counter-based backup rotation and manifest; top-level `last_active` pointer; `boot_load()` loads last-active slot with newest-slot fallback; `switch_to_slot()` for Load Game, `init_slot()` for New Game; `get_slot_summaries()` returns per-slot day/cash/last-played from manifest (with pre-summary fallback parsing)
- 2026-06-11 — [save] Legacy single-save migration: existing `user://saves/` data auto-migrated into slot 1 and last-active pointer set to slot 1; old `save_N.json` counter filenames unchanged per-slot
- 2026-06-11 — [save] `reset_providers()` added: calls `reset()` on any registered provider that implements it — `MetaManager` re-instantiates all 6 domain stores, `KnowledgeManager` re-instantiates `KnowledgeStore`
- 2026-06-11 — [save] `SaveManager.has_save()` deprecated → `has_any_save()`; `has_slot_data(slot)` per-slot check
- 2026-06-11 — [save] Boot sequence: `SaveManager.load()` renamed to `SaveManager.boot_load()`; `GameManager` calls `boot_load()` instead of `load()`
- 2026-06-11 — [start] Start page rewritten: `PlayButton` split into `NewGameButton` + `LoadGameButton`; slot picker overlay with 3-slot buttons showing day/cash summaries; New Game mode shows all slots (occupied → overwrite confirmation), Load Game mode shows only occupied slots; confirmation dialogs for overwrite; back button returns to main menu
- 2026-06-11 — [start] Scene file (`start_page_scene.tscn`): slot picker panel with `PickerTitle`, 3 `Slot*Button`s, `PickerBackButton`, `SpacerTop`/`SpacerBottom`, `OverwriteDialog` confirmation dialog; `PlayButton` → `NewGameButton` + `LoadGameButton` with `unique_name_in_owner = true`
- 2026-06-11 — [theme] `main_theme.tres`: StyleBoxFlat sub-resource color order reorganized (disabled/focus/hover before normal); UID attributes added to checkbox icon ext_resources; minor color tweaks (disabled bg 0.16/.18, border 0.22/.25); focus border style added
- 2026-06-11 — [docs] `dev/docs/plans/save_slots.md` and `dev/docs/plans/start_page_new_game.md` shipped and archived

### Save Diagnostics & Restore Hardening

- 2026-06-11 — [save] `SaveLoadContext` (RefCounted) push model replaces per-store pull accumulators: `ctx.warn()` for player-facing data-loss toasts, `ctx.info()` for debug-only detail + console parity
- 2026-06-11 — [save] `StoreBase.from_dict()` / `_apply_migrations()` require `SaveLoadContext`; `_migration_log` / `_restore_warnings` fields and their getters removed across all stores and managers
- 2026-06-11 — [save] `ItemEntry.from_dict(d, ctx)` — null returned on unresolvable anchor (was: silent zero-value entry); per-entry resolution failures via `ctx.info()` instead of discarded collector array
- 2026-06-11 — [save] Degraded detection in `StorageStore.from_dict()` is structural (resolved vs listed clue count) — no collector array needed
- 2026-06-11 — [save] Sniffing migrations (`anchor_revealed`/`inspected` → `unveiled`, `verified` → `hidden_ids` union) moved from `ItemEntry.from_dict()` into `StorageStore._apply_migrations()` v<2 branch
- 2026-06-11 — [save] `SaveManager.load()` constructs one `SaveLoadContext`, threads through provider dispatch, drains warnings/infos to `ToastManager`; `has_method` probing for old collector getters removed

### Pool Generation

- 2026-06-11 — [gen] `ItemGenerator` static class with full draw sequence: category → anchor (tier-weighted, nearest-tier fallback) → surface clues (uniform, no replacement, global min/max range) → rarity → hidden clues (domain scope, exclusive-group, at-most-one-override constraints)
- 2026-06-11 — [gen] `LotEntry.create()` uses `ItemGenerator.draw()` — authored item references replaced with pool-based generation at lot-draw time
- 2026-06-11 — [gen] `ItemEntry.from_generation()` factory for pool-assembled entries; `to_dict` / `from_dict` serializes composition form (anchor_id + surface_ids + hidden_ids + category_id)
- 2026-06-11 — [gen] `StorageStore._apply_migrations()` v<2 branch migrates shape keys and drops legacy `item_id` entries (ItemData/ItemRegistry no longer exist — composition-only runtime)
- 2026-06-11 — [data] Authored `data/yaml/items/*.yaml` (4 files) and `ItemData` resource removed; `ItemRegistry` autoload deleted
- 2026-06-11 — [tool] `dev/tools/balance_preview.py` added — Python simulation of item value distributions per lot config (10k draws, percentiles, content-health flags)
- 2026-06-11 — [economy] `Economy.SURFACE_CLUE_MIN` / `Economy.SURFACE_CLUE_MAX` (defaults 2,4) with 1–8 hard clamp

### Clue Schema Cleanup

- 2026-06-10 — [schema] `AnchorData` resource added (`data/definitions/anchor_data.gd`): anchors extracted out of the clue system into their own designer resource — `anchor_id`, `known_text`, `naming_priority`, `category_data`, `base_value`, and physical identity (`shape_id`, `sprite`, `weight_kg`, `tier`); anchors carry no discovery attribute/DC, effect op, or exclusive group
- 2026-06-10 — [schema] `ClueData` reduced to surface/hidden: `ClueType.ANCHOR` removed, anchor-only physical fields removed, half-wired `affinity_tags`/`tag_weights` draw metadata removed, `effect_op` domain is now `add | mul | override` (`override` = hidden-only base replacement, renamed from the overloaded "flat")
- 2026-06-10 — [schema] `ItemData` clue list split three ways: `anchor: AnchorData` + `surface_clues` + `hidden_clues` (plus `all_clues` combined getter); exactly-one-anchor and hidden-after-surface ordering are now guaranteed by construction
- 2026-06-10 — [runtime] `ItemEntry` veil state re-keyed to a single `unveiled` flag (`is_veiled()` reads it; legacy save keys `anchor_revealed`/`inspected` still accepted on load); anchor ids no longer live in `revealed_clue_ids` and the stale-anchor-id re-add special casing is gone; price pipeline reads `anchor.base_value` and matches the `override` op; `display_name` composes from mixed AnchorData/ClueData entries with anchor → surface → hidden tie-break
- 2026-06-10 — [registry] `AnchorRegistry` autoload added over `data/tres/anchors/`
- 2026-06-10 — [pipeline] `anchor_data.py` entity spec added (symmetric build/parse; validates category_scope, base_value > 0, shape whitelist, tier 1–5, known_text word cap); `item.py` rewritten for `anchor_id`/`surface_ids`/`hidden_ids` with list/type-agreement checks, ≤1 hidden override, exclusive-group uniqueness, and anchor-provided body naming; `clue.py` rewritten without anchor/affinity fields
- 2026-06-10 — [data] full YAML content mechanically converted: anchors authored under an `anchors:` section (`*_veil_NN` ids), items reference anchor/surface/hidden id lists, hidden `flat` renamed to `override`; all `.tres` regenerated including new `data/tres/anchors/`
- 2026-06-10 — [docs] `dev/docs/plans/clue_schema_cleanup.md` shipped and archived; the content half (generation standard, prompts, reference tables, full regen) lives on as `dev/docs/plans/clue_content_standard_regen.md`

---

### Clue Content Standard

- 2026-06-11 — [docs] Baseline review of post-cleanup YAML set: validator green, `_veil_NN` rename confirmed consistent, no `flat`-op or anchor-as-clue remnants; 5 empty categories + missing negative/override content + `yaml_stats.py` post-cleanup defect documented for the regen plan
- 2026-06-11 — [docs] Decision: drop `item_name` annotation field from items YAML (pipeline-ignored; display name composes from naming slots)
- 2026-06-11 — [docs] Draw rules recorded: tier weight curves for anchors, uniform surface/hidden draws, at most one override + one per exclusive_group per item, rarity frequency only (not hidden contents)
- 2026-06-11 — [prompts] `base.md` updated: `_anchor_NN` → `_veil_NN`, `anchor_id` ID standard added, anchors noted as separate resources not clues
- 2026-06-11 — [prompts] `category.md` updated: `super_category` field corrected from display strings to snake_case IDs matching `super_categories:` block
- 2026-06-11 — [prompts] `item.md` fully rewritten against post-cleanup schema: three-resource table, dedicated anchor schema, `add|mul|override` ops (no `flat`), three-way item schema (`anchor_id`/`surface_ids`/`hidden_ids`), effect budgets per tier with positive/negative mix, super-category personalities, fixed example (exclusive-group collision split into separate items)
- 2026-06-11 — [data] `data/yaml/reference_tables.yaml` added: per-category balancing targets (median, mean, stddev, min, max bands, condition expectations) for all 12 categories, with comparison spec header (band violations → `[WARN]`, schema violations → errors)
- 2026-06-11 — [docs] `dev/docs/plans/clue_content_standard.md` shipped and archived

---

### Clue Content Regen

- 2026-06-11 — [tool] `yaml_to_tres.py` `--force` flag added: deletes all existing `.tres` files in output directories before writing, ensuring no stale files linger from prior generations
- 2026-06-11 — [tool] `tres_to_yaml.py` deprecated: round-trip guarantee (AC4) waived; YAML is the sole authoring surface, `.tres` files are build artifacts
- 2026-06-11 — [tool] `yaml_stats.py` `__main__` guard added: script was unexecutable as a CLI tool despite documented usage; now runs correctly via `python dev/tools/yaml_stats.py --godot-root ...`
- 2026-06-11 — [audit] Full acceptance criteria audit against current YAML set: validator clean (AC1), all categories have ≥2 anchor variants + hidden==rarity + ≥1 negative surface/hidden per category pool + ≥1 override + no zero-effect clues (AC2), stats tool reports all 12 categories against reference tables with 21 band warnings (AC3), save compatibility confirmed — stale clue ids strip silently, removed items drop with warning (AC5), `item_name` field absent from all items YAML (AC6)
- 2026-06-11 — [docs] AC4 (yaml→tres→yaml lossless round trip) waived: `tres_to_yaml.py` deprecated; categories lose `shape_id`/`weight` on the reverse hop (entity spec gap), and absent-vs-empty representation differences on optional fields make losslessness impractical without schema harmonization that is not planned

---

### ItemEntry Layer Split & Manager-Mediated Mutations

- 2026-06-11 — [item_entry_refactor] Presentation logic stripped from `ItemEntry` into new `ItemEntryDisplayHelper` (`game/shared/item_display/`): all formatted text, color decisions, display-name composition, sort-key dispatch, and veiled-masking constants; `ItemEntry` now has zero dependencies on `KnowledgeManager` or any UI type
- 2026-06-11 — [item_entry_refactor] Three `KnowledgeManager.add_category_points()` calls removed from `ItemEntry` (`unveil()`, `attempt_clue()`, `advance_research()`); reveal-type XP flows via `EventBus.item_unveiled` / `EventBus.item_revealed` signals emitted by the owning Manager wrapper; `KnowledgeManager` subscribes and awards `REVEAL` XP
- 2026-06-11 — [item_entry_refactor] Mutation wrappers added to `RunManager`: `unveil_item(entry)`, `attempt_clue(entry, clue)`, `auto_reveal_all_surface(entry)`, `apply_trailer_damage()`; each calls the entry's mutator and emits the appropriate EventBus signal; `attempt_clue` computes attribute bonus internally; trailer damage loop moved entirely from `run_review_scene.gd` into the Manager
- 2026-06-11 — [item_entry_refactor] `MetaManager.research_item()` emits `EventBus.item_revealed` when `advance_research()` reveals a clue
- 2026-06-11 — [item_entry_refactor] `ItemEntry.unveil()` returns `bool` (true when flag actually flips); `apply_damage(ratio)` invariant-guarding mutator added (clamps `condition` at 0.0); `_naming_clue_pool()` → `get_naming_clue_pool()` (public); `_base_value()` → `get_base_value()` (public)
- 2026-06-11 — [item_entry_refactor] All scenes and UI components routed through Manager wrappers and `ItemEntryDisplayHelper`; direct mutations (`entry.unveil()`, `entry.attempt_clue()`, `entry.condition =`) and direct display calls (`entry.display_name`, `entry.estimated_value_text()`) eliminated from every scene
- 2026-06-11 — [item_entry_refactor] Hardcoded presentation duplicates in scenes deduplicated: `"???"` → `ItemEntryDisplayHelper.UNKNOWN_TEXT`, `Color(0.4, 1.0, 0.5)` → `ItemEntryDisplayHelper.PRICE_COLOR`, local `RARITY_NAMES` → `ItemEntryDisplayHelper.RARITY_NAMES`
- 2026-06-11 — [item_entry_refactor] `dev/standards/runtime_type_archetypes.md` created documenting the four archetypes (Entry/Instance, Store, Snapshot, Service) and the mutation-mediation rule ("scenes never mutate an Entry directly"); `CLAUDE.md` conventions updated to point to it

---

### Location Entry Backgrounds

- 2026-06-09 — [location_entry] `LocationData` gains `bg_exterior: Texture2D`, `bg_interior: Texture2D`, and `transition_type: String` exports; defaults to `"sliding_door"` when unset
- 2026-06-09 — [location_entry] `location_entry_scene.gd` rewritten: shows exterior bg on arrival, plays the configured transition wipe (`SlidingDoorTransition` or `FadeTransition`), swaps to interior bg while covered, holds an interior beat, then advances to lot browse; falls back to plain tween fade when textures are null
- 2026-06-09 — [location_entry] `location_entry_scene.tscn` cleaned up: dead `ClosedView`, `OpenView`, and `Background` ColorRect nodes removed; transition node instantiated at runtime
- 2026-06-09 — [pipeline] `location.py` `build_tres` auto-generates `bg_exterior`/`bg_interior` ExtResource entries from convention-based PNG paths; `transition_type` written as a string field; `parse_tres` round-trips both; `validate` errors on invalid `transition_type`
- 2026-06-09 — [pipeline] `gen_placeholder_backgrounds.py` updated: existing single-view functions renamed to `*_exterior`, matching `*_interior` variants added for both locations; existing PNGs renamed to `_exterior` suffix; interior PNGs generated
- 2026-06-09 — [data] `midtown_warehouse` YAML gains `transition_type: fade`; both location `.tres` files regenerated with texture ExtResources and transition field

---

### Deferred Save Throttle

- 2026-06-09 — [save] `SaveManager` gains two-tier save strategy: `mark_dirty()` sets a dirty flag and starts a throttle clock; `flush()` writes only when dirty; `_process()` auto-flushes at most once per 2 s (`THROTTLE_SEC`); `save()` clears dirty state on entry so a transaction save suppresses any pending deferred flush; `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` flushes on quit
- 2026-06-09 — [save] `SceneRouter` extracts `_navigate(scene)` helper — calls `SaveManager.flush()` before every `change_scene_to_packed`; all `go_to_*` methods route through it
- 2026-06-09 — [save] 7 recoverable micro-action call sites reclassified from `SaveManager.save()` to `SaveManager.mark_dirty()`: `repair_item`, `restore_item`, `research_item`, `set_active_car`, `begin_storage_slot`, `register_storage_items` (MetaManager), `unlock_perk` (KnowledgeManager); 7 irreversible transaction call sites unchanged
- 2026-06-09 — [docs] `dev/docs/systems/autoloads.md` SaveManager section updated to describe the two-tier Transaction Save / Deferred Save model with full call-site classification

---

### Save System Upgrade

- 2026-06-09 — [save_system] `ToastManager` autoload added (`global/autoloads/toast_manager.gd`): code-built CanvasLayer overlay (layer 128) with `show_warning()` (always visible) and `show_info()` (Debug.enabled only); toasts fade in, hold, then fade out via Tween; registered in `project.godot` after `Debug`
- 2026-06-09 — [save_system] `StoreBase` gains `_migration_log: Array[String]` and `get_migration_log()` (returns-and-clears); `MetaManager` and `KnowledgeManager` implement `get_migration_log()` aggregating from their owned stores; stores that override `_apply_migrations()` append human-readable entries per schema bump
- 2026-06-09 — [save_system] `SaveManager` rewritten: append-only counter-based saves at `user://saves/save_N.json`; manifest (`user://saves/manifest.json`) tracks latest counter as load fast-path; load falls back newest-first through candidates, toasting a warning on any skip; corrupt manifest recovers via filename scan; up to 10 files retained with best-effort cleanup; migration logs collected post-load and routed to `ToastManager.show_info()`
- 2026-06-09 — [save_system] Legacy `user://save.json` auto-migrated to `user://saves/save_1.json` on first boot and deleted best-effort
- 2026-06-09 — [save_system] `SaveManager.has_save()` API added; `start_page_scene.gd` updated to call it instead of accessing the removed `SAVE_PATH` constant directly

---

### Unified Debug System

- 2026-06-09 — [debug] `Debug` autoload added (`global/autoloads/debug.gd`): unified gate combining `OS.is_debug_build()` (build-time) and `SettingsStore.debug_mode` (user preference); exposes `enabled` property, `toggled` signal, and `set_debug_mode()` mutator
- 2026-06-09 — [debug] `SettingsStore.debug_mode` wired with setter + `debug_mode_changed` signal so any write (via `Debug.set_debug_mode()` or direct assignment) is runtime-correct
- 2026-06-09 — [debug] Auction scene debug overlay (`auction_scene.gd`) migrated from `OS.is_debug_build()` to `Debug.enabled`; connects `Debug.toggled` for reactive show/hide
- 2026-06-09 — [debug] Settings Overlay checkbox routes through `Debug.set_debug_mode()` instead of writing `SettingsStore.debug_mode` directly
- 2026-06-09 — [standards] `dev/standards/debug_standard.md` added: documents the two-layer debug gate, `Debug` autoload API, coding patterns (one-shot init, reactive toggle, conditional logic), node-source rules, and release safety
- 2026-06-09 — [standards] `block_scene_architecture_standard.md` updated: debug node references changed from `OS.is_debug_build()` to `Debug.enabled`
- 2026-06-09 — [docs] CLAUDE.md updated with Debug autoload in load order and debug standard pointer in Standards section

---

### Centralized Theme

- 2026-06-09 — [theme] `main_theme.tres` populated with centralized design tokens: color palette (primary/hover/pressed/disabled text), default font size 16, Button StyleBoxes (5 states), PanelContainer panel, TooltipPanel, HSeparator/VSeparator, container separation defaults (HBox/VBox=8, Grid=6×6)
- 2026-06-09 — [theme] Custom CheckBox icons added (`global/theme/icons/`): bright-border checked/unchecked/disabled PNGs visible on dark backgrounds; CheckBox theme entries with transparent StyleBoxEmpty background
- 2026-06-09 — [theme] Project-level theme set via `project.godot → [gui] theme/custom`; all scenes inherit automatically
- 2026-06-09 — [theme] Removed stale `NormalFont.ttf` ext_resource reference (font file was already deleted)
- 2026-06-09 — [standards] `dev/standards/theme_standard.md` added: documents palette, typography scale, spacing defaults, semantic gameplay colors, override rules, and incremental migration approach
- 2026-06-09 — [docs] CLAUDE.md updated with theme standard pointer in Standards section

---

### Start Page & Settings Overlay

- 2026-06-09 — [start_settings] `SettingsStore` autoload added (`global/autoloads/settings_store.gd`): persists master/sfx/music volume, fullscreen, debug_mode to `user://settings.json`; applies audio bus volumes and display mode on boot; toggles settings overlay on `ui_settings` input (Escape)
- 2026-06-09 — [start_settings] `SettingsOverlay` component added (`game/shared/settings_overlay/`): modal CanvasLayer (layer=100, PROCESS_MODE_ALWAYS) with Audio (Master/SFX/Music sliders), Display (fullscreen), and Gameplay (debug mode) sections; pauses tree on open, unpauses on close via `closed` signal
- 2026-06-09 — [start_settings] `StartPageScene` added (`game/meta/start/`): boots as `main_scene`; shows "New Game" or "Continue" based on save-file presence; routes to hub, settings overlay, or quit
- 2026-06-09 — [start_settings] `default_bus_layout.tres` added with Master/SFX/Music/UI buses; registered in `project.godot` under `[audio]`; `SceneRegistry.start_page` wired in `scene_router.tscn`
- 2026-06-09 — [standards] Block scene architecture standard updated: `%UniqueName` preferred over `$path` for node references in new/edited scenes; `$path` legacy-allowed in untouched code; `unique_name_in_owner = true` must be a property line, not a header attribute
- 2026-06-09 — [skills] `dev/skills/godot4_tscn_node_properties.md` added: exhaustive list of valid `.tscn` node header attributes (`name`, `type`, `parent`, `instance`, `unique_id`) vs. property lines; `unique_name_in_owner` worked example

---

### Save & Managers Refactor

- 2026-06-06 — [refactor] SaveManager stripped to a thin persistence coordinator (81 lines, no gameplay state); gameplay state distributed to 10 Store archetypes under `common/gameplay/store/` — 8 persisting (EconomyStore, GarageStore, StorageStore, SlotStore, ProgressStore, CustomersStore, KnowledgeStore) and 2 session-scoped (RunStore, LotStore) — all extending `StoreBase` with `section_id/to_dict/from_dict/_store_version/_apply_migrations`; Managers (MetaManager, KnowledgeManager) register as providers and coordinate cross-domain transactions; RunManager owns RunStore + LotStore factories and run-phase mutations
- 2026-06-06 — [refactor] Meta↔Knowledge dependency cycle broken via EventBus signals (`sale_resolved`, `item_repaired`, `item_restored`, `run_resolved`); MetaManager emits post-commit, KnowledgeManager subscribes for XP accrual; `upgrade_attribute` transaction moved to MetaManager
- 2026-06-06 — [refactor] RunRecord decomposed into RunStore (per-run cumulative state) + LotStore (per-lot mutable state: lot_entry, actions_remaining, won_items); RunManager owns AP deficit-refill handoff at lot boundaries; `RunResult` Snapshot added for run-end economics handoff
- 2026-06-06 — [refactor] All Stores use private backing vars + getter-only properties (language-enforced read-only); collection getters return `.duplicate()`; 35+ proxy properties removed from managers; scenes access state via `MetaManager.economy.cash`, `RunManager.lot.actions_remaining`, etc.
- 2026-06-06 — [refactor] Per-store versioned migrations replace top-level `run_migrations()`; legacy flat-save fallback and schema 1→2 migration removed; `RegistryCoordinator` removed; `ResourceRegistry` base class added for all registries
- 2026-06-06 — [refactor] `autoload/` → `autoloads/` folder rename; runtime types organized into archetype subfolders (`instance/`, `store/`, `snapshot/`, `service/`); `Customer` → `CustomerEntry`; `location_select` / `location_entry` → `*_scene` suffix
- 2026-06-06 — [docs] Systems docs L2 audit; `data_architecture.md` vision added; naming conventions updated for singular archetype folders; `DaySummary` reclassified as Snapshot

### Customer Sell UX Polish

- 2026-06-01 — [customer-sell] Fixed grid rotation pivot drift: `_grab_index` pins the grabbed cell under the cursor across Q/E rotations; list picks anchor to shape centroid
- 2026-06-01 — [customer-sell] Bidirectional list↔grid hover sync via `set_external_hover_item()`; hover state re-emitted after place/cancel to clear stale highlights
- 2026-06-01 — [customer-sell] Back to Hub button moved to bottom FooterRow; CustomerTabsRow wrapped in ScrollContainer to handle overflow with many customers
- 2026-06-01 — [customer-sell] `CURSOR_DRAG` feedback while holding an item; `queue_redraw()` in `_apply_state_style` for immediate row colour updates

### Live Budget Label

- 2026-05-31 — [auction] Budget label pinned to top-right corner showing remaining cash minus committed run costs; refreshes live after every player bid

### Time-Slot Day Structure & Storage AP Economy

- 2026-05-30 — [day-structure] 3-slot day (Morning/Afternoon/Evening); hub slot tray replaces Day Pass; Auction consumes slots 1+2, returns player for Evening
- 2026-05-30 — [day-structure] Storage AP economy: per-slot pool of 10 AP, refreshed each Storage slot; Repair (2 AP), Restore (2 AP), Research (4 AP) execute immediately
- 2026-05-30 — [day-structure] Deterministic storage Research: fixed (5 + Investigation) progress per AP spend, reveals clue at accumulated progress ≥ DC; `ItemEntry.research_progress` persists across slots and days
- 2026-05-30 — [day-structure] Two-tier auction AP: `inspection_ap_cap` (10) per-lot cap + `refill_metric` (30) reserve; deficit refill at lot boundaries; HUD max uses cap instead of `action_quota`
- 2026-05-30 — [day-structure] Open Shop scales nightly customer count by selling-slot commitment: 1→2–3, 2→4–6, 3→7–10
- 2026-05-30 — [day-structure] `end_day()` replaces `advance_days()`; always advances exactly one calendar day; folds pending run economics from `resolve_run()`
- 2026-05-30 — [day-structure] `resolve_run()` returns void; stashes run economics as pending, sets slot=3 (Evening), navigates to hub; day summary fires from hub when day ends
- 2026-05-30 — [day-structure] Save migration: `research_slots` array retired; partial `research_days_spent` seeded into `ItemEntry.research_progress`; `current_slot`, `storage_ap`, `selling_slots_today` added to schema
- 2026-05-30 — [day-structure] `ResearchSlot` lifecycle stripped (enums, dicts, slot management); math helpers (`apply_repair`, `apply_restore`, caps) kept

### Day Summary Rework

- 2026-05-29 — [day-summary] `DaySummary` carries customer sales total/detail; `advance_days()` captures `customer_sales_today` before the nightly ledger clears; net change includes sales revenue; summary scene renders a customer-sales section; post-run routes through the day-summary scene (`f873cc7`).

### Value Policy Cleanup

- 2026-05-29 — [pricing] `item_price` simplified to `(appraised|verified) × condition_multiplier`; `MarketManager`, `PriceConfig`, `ItemViewContext` removed; condition kept as an independent ×0.25–×4.0 system (`41a5945`).

### Unified Customer Selling

- 2026-05-29 — [customer-sell] `Customer` runtime type with match-biased nightly generation, `SellMath` conservative/aggressive helpers, customer-sell scene with car-grid packing + dice UI, `customer_sales_today` ledger (`236f636`).
- 2026-05-29 — [cleanup] Legacy merchant negotiation, special orders, and deprecated selling helpers removed; `ItemEntry` price logic deduplicated, research moved to `ResearchSlot` (`9b4dfe9`, #108).

### YAML Content Regeneration

- 2026-05-28 — [content] All 128 clues rewritten to 1-word `known_text` with naming entries assigned; validator enforces body+qualifier; names reconciled (`19c6caf`).

### Dynamic Naming Rules

- 2026-05-28 — [naming] Priority-based `display_name` composition from naming clues, 3-word `known_text` ceiling, full-reveal validation (`3c4c423`).

### Inspection Refinement

- 2026-05-28 — [inspection] `DisplayState` (veiled/unveiled/verified), clue chain reveal, lot unveil probability; `verified` as a computed property (`e59d58e`).

### Clue Independence + Attribute System

- 2026-05-27 — [items] Identity layers and the skill system replaced by clue-based add-then-mul pricing, 5 SPECIAL attributes, and dice-roll inspection; `ItemData.base_price` deprecated (`1ff40d0`, #107).

### Cargo Scene Refactor

- 2026-05-25 — [cargo] Two-column layout with scrollable item list (`CargoItemRow`), value/weight/condition/shape legibility, inline trailer slots, run summary panel; 10×4 temp grid removed (`0113112`).

### Storage Authenticate

- 2026-05-14 — [storage] Hub final-layer resolution and Storage Authenticate: verified flag, rarity-based duration, slot action (`4190a4b`).

### Foundations

- 2026-05-04 — [items] Pre-redesign foundations: item/entry data model, veil/identity-layer inspection, AP-grid inspection, runtime veil cleanup. The veil and identity-layer models were later superseded by the clue system above.

### Hub & Home

- 2026-05-01 — [hub] Hub scene with Next Run / Storage / Sell / Vehicle / Knowledge / Day Pass navigation buttons
- 2026-05-01 — [hub] Header displaying Mastery Rank, Balance, and Storage item count
- 2026-05-01 — [hub] Day Pass confirmation dialog routes through `MetaManager.advance_days(1)` to `DaySummaryScene`
- 2026-05-01 — [hub] Vehicle button replaces Van info popup; routes to `GameManager.go_to_vehicle_hub()`
- 2026-05-01 — [hub] `_refresh_display()` refreshes header on return from `DaySummaryScene`
- 2026-05-01 — [knowledge] Knowledge Hub entry scene routing to Mastery / Attributes / Perks sub-panels
- 2026-05-01 — [day-summary] `DaySummaryScene` shared by hub day-pass and run-review flows; reads from `GameManager.consume_pending_day_summary()`, falls back to hub if empty
- 2026-05-01 — [day-summary] `DaySummary` value object with `start_day` / `end_day` / `days_elapsed`, run fields, `cargo_count`, `living_cost`, `completed_actions`, `net_change`, `has_run_data()` gate
- 2026-05-01 — [day-summary] `DaySummary.cargo_count` + regrouped scene (TripExpensesGroup / DailyGroup / CargoCountLabel); trip expenses, daily living, cargo summary no longer share a column
- 2026-05-01 — [storage] Storage scene with research-slot assignment (Repair / Restore / Research), slot removal, per-action disabled-reason tooltips
- 2026-05-01 — [storage] `Column.RESEARCH_STATUS` on storage list reflects current slot action or completion state
- 2026-05-01 — [storage] Hub Storage button badge shows `"Storage (N done)"` when research slots complete; refreshed on `_refresh_display()`
- 2026-05-01 — [hub] Sell button routes to customer-sell scene; replaces old Merchant button

### Knowledge

- 2026-05-01 — [knowledge] `SaveManager.category_points` / `attribute_levels` / `unlocked_perks` persistence
- 2026-05-01 — [knowledge] Four-layer mastery model: `get_category_rank()`, `get_super_category_rank()`, `get_mastery_rank()`
- 2026-05-01 — [knowledge] Five `AttributeData` resources + attribute value/upgrade API (flat $1000/level)
- 2026-05-01 — [knowledge] `PerkData` + perk unlock/has/get API with attribute-threshold gating
- 2026-05-01 — [knowledge] `KnowledgeAction` enum: `INSPECT`, `REVEAL`, `APPRAISE`, `REPAIR`, `SELL`, `RESTORE`
- 2026-05-01 — [knowledge] Knowledge Hub scene + Mastery / Attributes / Perk sub-panels
- 2026-05-01 — [knowledge] `KnowledgeManager.validate()` registered with `RegistryCoordinator`; boot-time audit of registries + unlocked perk ids
- 2026-05-01 — [knowledge] Skill system fully removed; SPECIAL-style attributes replace it

### Vehicle

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

### Item Display

- 2026-05-01 — [display] `ItemViewContext` removed; components take `ItemEntry` directly; no stage enum, no per-stage branching, no merchant/order side-channels
- 2026-05-01 — [display] `ItemRow` / `ItemListPanel` read every field through `ItemEntry` getters
- 2026-05-01 — [display] `ItemRow` column set reduced to display columns only; transaction columns removed with merchant channel
- 2026-05-01 — [display] `ItemListPanel`: reusable sortable table; runtime-built headers; per-row selection state
- 2026-05-01 — [display] Column order matches columns array passed at `setup()`
- 2026-05-01 — [display] `ItemCard`: clue-aware inspection card; veiled items hide derived fields and show `"???"`
