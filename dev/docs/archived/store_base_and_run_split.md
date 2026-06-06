# StoreBase Extraction + RunRecord Decomposition

Implementation spec — see `dev/standards/implementation_spec_standard.md`. Introduces a shared base class for all Stores, renames RunRecord → RunStore + DaySummary → DaySnapshot under the archetype taxonomy (see `CLAUDE.md`), and extracts service logic from RunRecord into RunManager so it aligns with the MetaManager pattern.

## Goal

Unify the Store archetype behind a concrete base class, then decompose RunRecord into a pure state container (RunStore) and service logic on RunManager — bringing RunManager in line with MetaManager's "Manager holds Stores, drives them through coordinated methods" pattern. DaySummary is reclassified as DaySnapshot (Snapshot archetype) in the same pass.

## Relational Context

- **StoreBase → all Stores**: new `StoreBase extends RefCounted` becomes the single parent. All 7 existing persisting Stores and the new RunStore inherit it. StoreBase provides default no-op `section_id/to_dict/from_dict/migrate/validate`. Persisting Stores override all five; RunStore overrides none (session-scoped, never registered with SaveManager).
- **SaveManager → section providers**: SaveManager currently duck-types `to_dict/from_dict` on `_sections: Array` and `migrate/validate` on `_managers: Array`. Both arrays stay untyped `Array` (SaveManager registers Managers, not Stores directly — MetaManager/KnowledgeManager fan out to their own Stores). No SaveManager change is needed.
- **RunManager → RunStore**: RunManager becomes the sole factory and driver of RunStore. The static factory `RunRecord.create()` moves to RunManager as `create_run_store()`. The static AP resolution helpers (`_resolve_inspection_ap_cap`, `_resolve_refill_reserve`) and `compute_travel_costs()` move to RunManager as private methods. RunManager already owns the lifecycle (`run_record = null` between runs); this change adds creation and resolution to that ownership.
- **RunStore.set_lot()**: stays on RunStore. It is a self-contained mutator that guards the two-tier AP refill invariant using only its own fields — same pattern as `EconomyStore.spend()` or `StorageStore.register_entry()`. RunManager does not mediate lot-setting.
- **MetaManager.resolve_run()**: currently takes `RunRecord`. Parameter type changes to `RunStore`. The method reads fields only — no behavioral coupling to the factory or resolution helpers that are moving.
- **SlotStore.stash_pending_run()**: currently takes `RunRecord`. Parameter type changes to `RunStore`. Reads five fields; no other coupling.
- **DaySummary → DaySnapshot**: one-shot value object consumed by SceneRouter and the day-summary scene. The scene class, route methods (`go_to_day_summary`, `consume_pending_day_summary`), and packed-scene field keep their names — only the data type annotation changes.
- **Call sites for RunManager.run_record**: every run-phase scene reads/writes `RunManager.run_record`. Accessor renames to `RunManager.run_store`. Local var/param types follow.
- **Location Select → RunManager**: currently calls `RunRecord.create(location, car)` and assigns to `RunManager.run_record`. Changes to `RunManager.create_run_store(location, car)` which internally creates, initializes, assigns, and returns the RunStore.

## Scope

### Included

- New `common/gameplay/store/store_base.gd` with default no-op implementations.
- All 7 existing Stores: change `extends RefCounted` → `extends StoreBase`, remove empty `migrate()`/`validate()` overrides (keep non-empty ones).
- Rename `RunRecord` → `RunStore`; move `run_record.gd` (+`.uid`) into `common/gameplay/store/`.
- Extract factory + resolution + travel-cost logic from RunStore into RunManager.
- Rename `DaySummary` → `DaySnapshot`; move `day_summary.gd` (+`.uid`) into `common/gameplay/snapshot/`.
- Update all call-site accessor names, type annotations, local vars/params.
- Update `CLAUDE.md`, system docs, naming conventions, and `TODO.md`.

### Excluded

- Any behavioral change to AP, economics, day-end math, or customer selling.
- Renaming the day-summary scene, its route methods, or its packed-scene field.
- Adding a save payload to RunStore or registering it with SaveManager.
- Changes to SaveManager itself (it registers Managers, not Stores).
- Editing archived docs or `CHANGELOG.md`.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/store/store_base.gd` | Small (new) | Base class: default `section_id/to_dict/from_dict/migrate/validate` |
| `common/gameplay/store/economy_store.gd` | Small | `extends StoreBase`, remove empty `migrate()`/`validate()` |
| `common/gameplay/store/garage_store.gd` | Small | `extends StoreBase`, keep non-empty `migrate()`, remove empty `validate()` |
| `common/gameplay/store/storage_store.gd` | Small | `extends StoreBase`, keep non-empty `migrate()`, remove empty `validate()` |
| `common/gameplay/store/slot_store.gd` | Small | `extends StoreBase`, remove empty `migrate()`/`validate()`; param type `RunRecord` → `RunStore` |
| `common/gameplay/store/progress_store.gd` | Small | `extends StoreBase`, remove empty `migrate()`/`validate()` |
| `common/gameplay/store/customers_store.gd` | Small | `extends StoreBase`, remove empty `migrate()`/`validate()` |
| `common/gameplay/store/knowledge_store.gd` | Small | `extends StoreBase`, keep non-empty `migrate()`, remove empty `validate()` |
| `common/gameplay/run_record.gd` → `common/gameplay/store/run_store.gd` | Medium | Rename class → `RunStore`, `extends StoreBase`; strip factory + resolution + travel-cost methods; keep `set_lot()` and all state fields |
| `common/gameplay/day_summary.gd` → `common/gameplay/snapshot/day_snapshot.gd` | Small | Rename class → `DaySnapshot`; header reframed as Snapshot |
| `global/autoloads/managers/run_manager.gd` | Medium | Rename field → `run_store: RunStore`; absorb `create_run_store()`, `_resolve_inspection_ap_cap()`, `_resolve_refill_reserve()`, `_compute_travel_costs()` |
| `global/autoloads/managers/meta_manager.gd` | Small | `resolve_run` param type → `RunStore`; `end_day` return type → `DaySnapshot` |
| `global/autoloads/scene_router/scene_router.gd` | Small | Pending field + param + return type → `DaySnapshot`; keep route method names |
| `game/meta/location_select/location_select.gd` | Small | `RunManager.create_run_store(...)` instead of `RunRecord.create(...)` |
| `game/run/location_entry/location_entry.gd` | Small | Accessor rename |
| `game/run/lot_browse/lot_browse_scene.gd` | Small | Accessor + local type |
| `game/run/auction/auction_scene.gd` | Small | Accessor reads/writes + local type |
| `game/run/inspection/inspection_scene.gd` | Small | Accessor reads/writes |
| `game/run/inspection/action_popup/lot_action_bar.gd` | Small | Accessor reads |
| `game/run/cargo/cargo_scene.gd` | Small | Accessor reads/writes |
| `game/run/reveal/reveal_scene.gd` | Small | Accessor reads |
| `game/run/run_review/run_review_scene.gd` | Small | Accessor reads + docstring |
| `game/meta/day_summary/day_summary_scene.gd` | Small | Consumed-value type → `DaySnapshot`; keep class/scene name |
| `common/gameplay/lot_entry.gd` | Small | Docstring mention |
| `dev/docs/systems/autoloads.md` | Small | RunManager row updated |
| `dev/docs/systems/day_slot_economy.md` | Small | `RunRecord` mentions → `RunStore` |
| `dev/docs/systems/meta/vehicle.md` | Small | `RunRecord` → `RunStore` |
| `dev/docs/systems/meta/hub_home.md` | Small | `DaySummary` → `DaySnapshot` |
| `dev/standards/naming_conventions.md` | Small | Class-name example updated |
| `CLAUDE.md` | Small | Current Phase note; any stale `RunRecord`/`DaySummary` mentions |
| `dev/docs/plans/demo_summary.md` | Small | `RunRecord` mention → `RunStore` |
| `TODO.md` | Small | Delete plan pointer when shipped |

## Implementation Notes

- `StoreBase` is a concrete class, not abstract. GDScript has no `abstract` keyword; the default no-ops serve the same purpose. A Store that forgets to override `section_id()` returns `""` — SaveManager never sees it because only Managers register as section providers, and they fan out to their own stores explicitly.
- RunStore inherits StoreBase but overrides nothing from the save interface. It gains no `section_id`, `to_dict`, or `from_dict`. It is not registered with SaveManager by any Manager. This is the "session-scoped Store" pattern described in CLAUDE.md.
- `RunManager.create_run_store(location, car)` creates the RunStore, sets all fields, calls the private resolution helpers, assigns `self.run_store`, and returns it. Location Select calls `RunManager.create_run_store(...)` and uses the returned ref only for an immediate null-assert or navigation guard — it does not keep a second reference.
- `set_lot()` stays on RunStore. It touches only `lot_entry`, `last_lot_won_items`, `actions_remaining`, `refill_metric` — all fields it owns. Same invariant-guarding pattern as other Store mutators.
- For DaySnapshot: change only type annotations. Do not rename `go_to_day_summary`, `consume_pending_day_summary`, `scenes.day_summary`, the `@export var day_summary` packed-scene field, or `DaySummaryScene`.
- Orphan `.uid` files in `common/gameplay/` root (leftover from the Owner→Store rename) can be cleaned up in this pass.
- After edits, run `python dev/tools/lint_standards.py --files <changed>` then reload Godot.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| A scene reads `RunManager.run_store` before Location Select creates it | Unchanged — existing null-assert in location entry still guards |
| Save files written before this change | Unaffected — neither RunRecord nor DaySummary was ever serialized |
| A Store subclass forgets to override `section_id()` | Returns `""`; harmless because SaveManager never sees individual Stores — Managers fan out explicitly |

## Acceptance Criteria

1. The project loads in Godot with no unresolved `RunRecord` or `DaySummary` identifiers in active code.
2. All 7 persisting Stores and RunStore extend StoreBase.
3. RunStore carries no save payload and is not registered with SaveManager.
4. RunManager owns the factory and AP resolution; RunStore holds only state + `set_lot()`.
5. Run-phase behavior — inspection AP, auction wins, cargo packing, run review — is identical.
6. The day-summary screen renders the same figures from a DaySnapshot; net_change is unchanged.
7. Standards lint passes on every changed file.
