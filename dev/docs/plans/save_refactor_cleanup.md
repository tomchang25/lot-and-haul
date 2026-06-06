# Save Refactor Cleanup

Post-review cleanup for the save-refactor branch. Fixes Store contract violations, dead code, stale documentation, signal ordering, and missing guards identified during PR review.

## Goal

Harden the save-refactor branch before merge: fix the KnowledgeStore contract violation, remove dead fields/code, update all stale RegistryCoordinator references in docs and standards, correct signal ordering in resolve_customer_sale, and add defensive asserts to run-phase scenes.

## Relational Context

- **KnowledgeStore → KnowledgeManager**: KnowledgeManager holds `_knowledge: KnowledgeStore` as a private field. External code (scenes, ItemEntry) accesses KnowledgeStore state through KnowledgeManager's public API only — never through the store directly. Making KnowledgeStore fields private does not change any external call site.
- **ItemEntry → KnowledgeManager (direct call)**: ItemEntry calls `KnowledgeManager.add_category_points()` in `attempt_clue()`, `advance_research()`, and `unveil()`. These are notification-style XP grants — the caller's correctness does not depend on the result. Per project convention this should use EventBus, but changing it is out of scope for this cleanup (noted in Excluded).
- **MetaManager → EventBus → KnowledgeManager (sale_resolved)**: MetaManager emits `sale_resolved` inside `resolve_customer_sale()`. KnowledgeManager subscribes and calls `_knowledge.add_points()`. The emit currently fires before `economy.earn()` and `customers.record_sale()`. Moving the emit after those calls changes no subscriber behavior today (KnowledgeManager reads neither cash nor sales in its handler).
- **SaveManager → section providers (to_dict/from_dict)**: SaveManager iterates `_sections` and calls `to_dict()` / `from_dict()` via duck typing. No type assertion on registration. Adding an assert in `register_section()` / `register_manager()` catches wiring errors at boot.
- **RunStore → RunManager**: RunManager owns RunStore (session-scoped, nullable). `_net` is a RunStore backing field with a getter but no mutator — dead since extraction from RunRecord.
- **RunManager.lot → run-phase scenes**: Scenes access `RunManager.lot.*` without null guards. `RunManager.lot` is set by `set_lot()` before scene entry, but an assert makes the contract explicit, matching the pattern already used in `location_entry.gd` for `RunManager.run`.
- **autoloads.md, registries.md → RegistryCoordinator (deleted)**: Both docs reference `RegistryCoordinator` which was deleted. SaveManager now owns `register_manager()`, `run_migrations()`, `run_validation()`. The boot orchestration section and registry checklist need rewriting.
- **INDEX.md → plans/store_base_and_run_split.md**: INDEX.md links this as a live plan but the file was archived. The entry should be removed.

## Scope

### Included

- Phase 1: KnowledgeStore contract fix (private backing fields + getters)
- Phase 2: Dead code removal (RunStore._net, lot_action_bar.gd assessment)
- Phase 3: Stale documentation (autoloads.md, registries.md, INDEX.md, CLAUDE.md autoload list)
- Phase 4: Signal ordering and defensive guards

### Excluded

- ItemEntry direct calls to KnowledgeManager (EventBus migration) — separate chore
- Implicit save coupling in KnowledgeManager event handlers — acceptable documented contract
- StorageStore untyped Array — minor, separate chore
- GarageStore.set_active missing owned-car guard — manager guards it upstream
- from_dict `is float` fragility — acceptable for JSON-only path

## Files to Change

### Phase 1 — KnowledgeStore contract

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/store/knowledge_store.gd` | Medium | Rename 3 public vars to `_`-prefixed, add getter-only properties, update all internal references |

### Phase 2 — Dead code

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/store/run_store.gd` | Small | Remove `_net` backing field and `net` getter |
| `game/run/inspection/action_popup/lot_action_bar.gd` | Small | Assess and remove if confirmed dead (hidden in _ready, never shown) |
| `game/run/inspection/inspection_scene.gd` | Small | Remove `_action_bar` reference if lot_action_bar is removed |
| `game/run/inspection/inspection_scene.tscn` | Small | Remove LotActionBar node if confirmed dead |

### Phase 3 — Stale documentation

| File | Change Size | Purpose |
| --- | --- | --- |
| `dev/docs/systems/autoloads.md` | Medium | Rewrite Boot Orchestration section (SaveManager owns it now); fix MetaManager paragraph (store-exposure, not proxies) |
| `dev/standards/registries.md` | Small | Replace 3 RegistryCoordinator references with SaveManager |
| `dev/docs/INDEX.md` | Small | Remove stale link to plans/store_base_and_run_split.md |
| `global/autoloads/save_manager.gd` | Small | Remove stale RegistryCoordinator mention in header comment |
| `global/utils/registry_audit.gd` | Small | Update stale RegistryCoordinator comment |
| `CLAUDE.md` | Small | Add SceneRouter to autoload list |

### Phase 4 — Signal ordering and guards

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoloads/managers/meta_manager.gd` | Small | Move `sale_resolved` emit after `economy.earn()` and `customers.record_sale()` |
| `global/autoloads/save_manager.gd` | Small | Add `assert(section.has_method("to_dict"))` in register_section, `assert(manager.has_method("migrate"))` in register_manager |
| `game/run/auction/auction_scene.gd` | Small | Add `assert(RunManager.lot != null)` in _ready |
| `game/run/inspection/inspection_scene.gd` | Small | Add `assert(RunManager.lot != null)` in _ready |
| `game/run/cargo/cargo_scene.gd` | Small | Add `assert(RunManager.lot != null)` in _ready |
| `game/run/lot_browse/lot_browse_scene.gd` | Small | Add `assert(RunManager.lot != null)` in _ready |
| `game/run/reveal/reveal_scene.gd` | Small | Add `assert(RunManager.lot != null)` in _ready |

## Implementation Notes

**Phase 1 — KnowledgeStore**: The three fields (`category_points`, `attribute_levels`, `unlocked_perks`) become `_category_points`, `_attribute_levels`, `_unlocked_perks`. Add read-only getter properties following the exact pattern used in every other Store (see EconomyStore, ProgressStore). The getters for Dictionary fields should return the dictionary directly (not duplicate — callers are trusted KnowledgeManager methods). Update all internal references in the same file (mutators, `to_dict`, `from_dict`, `migrate`). No external code accesses these fields directly — KnowledgeManager's public API is the interface.

**Phase 2 — RunStore._net**: Simply delete lines 19 and 59-60. No caller references `run.net` in any scene file (verified by grep). For lot_action_bar: confirm it is not referenced by any scene other than inspection_scene.gd's `_action_bar` field. If the `.tscn` has the node and the script hides it immediately in `_ready()` without ever showing it, remove the node, the script, and the field. If there's any `show()` call path, keep it and just note it as vestigial.

**Phase 3 — autoloads.md**: The Boot Orchestration section should describe SaveManager owning `register_section()` and `register_manager()`, with GameManager calling `SaveManager.run_migrations()` and `SaveManager.run_validation()` after `SaveManager.load()`. The MetaManager paragraph should say stores are plain public fields and scenes read state directly via `MetaManager.<store>.<field>` — no proxies.

**Phase 4 — sale_resolved ordering**: In `resolve_customer_sale()`, move the `for entry` / `EventBus.sale_resolved.emit(...)` loop to after `economy.earn()` and `customers.record_sale()` (but before `SaveManager.save()`). The signal semantically means "this sale is committed" — emit it when it actually is.

## Acceptance Criteria

1. KnowledgeStore has no raw public vars — all three fields use underscore-prefixed backing + getter-only property.
2. RunStore has no `_net` field or `net` getter.
3. No file in the repo references `RegistryCoordinator` (grep clean).
4. autoloads.md Boot Orchestration describes SaveManager, not RegistryCoordinator.
5. autoloads.md MetaManager paragraph describes store-exposure pattern, not proxies.
6. registries.md checklist references SaveManager for registration.
7. INDEX.md contains no broken links to archived files.
8. CLAUDE.md autoload list includes SceneRouter.
9. `sale_resolved` emits after `economy.earn()` and `customers.record_sale()`.
10. SaveManager asserts method existence on registration.
11. All run-phase scenes that access `RunManager.lot` assert it is non-null in `_ready()`.
12. Dead lot_action_bar code is removed (or documented if kept intentionally).
