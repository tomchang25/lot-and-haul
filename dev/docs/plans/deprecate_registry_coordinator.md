# Deprecate RegistryCoordinator

Implementation spec — see `dev/standards/implementation_spec_standard.md`. Removes the RegistryCoordinator autoload by relocating its migrate/validate responsibilities to their rightful domain owners.

## Goal

Remove the RegistryCoordinator autoload. Its two responsibilities — boot-time migration fan-out and validation fan-out — are architectural leaks: registries currently mutate manager/store state they do not own, and the coordinator exists only to enable that cross-boundary reach. Relocate each piece to its domain owner and let SaveManager drive the fan-out temporarily.

## Relational Context

- `RegistryCoordinator` duck-types `migrate()` / `validate()` on every node that called `register(self)`. Registered nodes today: 6 registries (Item, Car, Location, Category, SuperCategory, Clue) + MetaManager + KnowledgeManager.
- `CarRegistry.migrate()` reads `MetaManager._garage` (GarageStore) to check whether a starter van exists, then calls `MetaManager.add_car()` and `MetaManager.set_active_car()`. This is a registry writing to a store it does not own — the logic belongs in GarageStore.
- `CategoryRegistry.migrate()` reads `KnowledgeManager.category_points` and calls `KnowledgeManager.erase_category_points()` to drop orphaned keys. This is a registry writing to a manager/store it does not own — the logic belongs in KnowledgeStore or KnowledgeManager.
- `ResourceRegistry` (base class) calls `RegistryCoordinator.register(self)` at end of `_ready()`. After removal, this call and the coordinator reference are deleted.
- `MetaManager` and `KnowledgeManager` already implement internal `migrate()` / `validate()` aggregation over their stores. They already register with RegistryCoordinator, so the coordinator's fan-out to them is pure indirection.
- `SaveManager` holds `_sections: Array` of all section providers (the 6 persisting stores + KnowledgeStore, registered via `register_section()`). It currently owns only file I/O and schema-version migration (v1→v2). The new fan-out methods (`run_migrations()`, `run_validation()`) iterate `_sections` — but the stores' `migrate()` / `validate()` are called by their owning managers, not directly. SaveManager must call the managers, not the stores.
- `SaveManager` does not currently hold references to MetaManager or KnowledgeManager — only to their stores (via `register_section()`). The fan-out needs manager-level references; approach: SaveManager adds a parallel `_managers` list that MetaManager and KnowledgeManager register with (or SaveManager discovers them by walking `_sections` owners — TBD at implementation).
- `GameManager._ready()` currently calls `RegistryCoordinator.run_migrations()` then `RegistryCoordinator.run_validation()`. After the change, it calls `SaveManager.run_migrations()` then `SaveManager.run_validation()`.
- Registry validation (non-empty assert) is a self-check, not a cross-system concern. Each registry can assert in its own `_ready()` via the ResourceRegistry base class, with no coordinator involvement.
- `LocationRegistry.validate()` checks that every weight key resolves against CategoryRegistry and SuperCategoryRegistry. This is a cross-registry data-integrity check that should live in the YAML pipeline (`validate_yaml.py`), not at runtime.

## Scope

### Included

- Move CarRegistry starter-van logic into GarageStore.migrate() (or MetaManager.migrate()).
- Move CategoryRegistry orphan-key cleanup into KnowledgeStore.migrate() (or KnowledgeManager.migrate()).
- Add non-empty assert to ResourceRegistry._ready() (replaces coordinator-driven validate for registries).
- Add cross-reference validation to validate_yaml.py (LocationRegistry weight keys vs category/super_category ids).
- Add run_migrations() and run_validation() to SaveManager, calling MetaManager and KnowledgeManager.
- Update GameManager._ready() to call SaveManager instead of RegistryCoordinator.
- Delete registry_coordinator.gd, its autoload entry, and all register() calls.
- Update CLAUDE.md autoload list.

### Excluded

- Refactoring SaveManager's role beyond temporary fan-out host (future work).
- Changing the store migrate/validate interface or adding version-based save migration (separate TODO item).
- Modifying any runtime game behavior.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoload/registry_coordinator.gd` | Delete | Remove the autoload entirely |
| `common/gameplay/resource_registry.gd` | Small | Remove `RegistryCoordinator.register(self)` call; add non-empty assert in `_ready()` |
| `global/autoload/registries/car_registry.gd` | Small | Delete `migrate()` — logic moves to GarageStore |
| `global/autoload/registries/category_registry.gd` | Small | Delete `migrate()` and `validate()` — logic moves to KnowledgeStore/KnowledgeManager |
| `global/autoload/registries/location_registry.gd` | Small | Delete `validate()` — cross-ref check moves to YAML pipeline |
| `common/gameplay/store/garage_store.gd` | Small | Add starter-van migration logic to `migrate()` |
| `common/gameplay/store/knowledge_store.gd` (or `knowledge_manager.gd`) | Small | Add orphan category-key cleanup to `migrate()` |
| `global/autoload/save_manager.gd` | Medium | Add `run_migrations()` and `run_validation()` that call MetaManager/KnowledgeManager; add manager registration mechanism |
| `global/autoload/managers/meta_manager.gd` | Small | Register with SaveManager's manager list |
| `global/autoload/managers/knowledge_manager.gd` | Small | Register with SaveManager's manager list |
| `global/autoload/game_manager/game_manager.gd` | Small | Replace RegistryCoordinator calls with SaveManager calls |
| `dev/tools/validate_yaml.py` | Medium | Add LocationRegistry-style cross-reference checks (weight keys vs category/super_category ids) |
| `project.godot` | Small | Remove RegistryCoordinator autoload entry |
| `CLAUDE.md` | Small | Remove RegistryCoordinator from autoload list |

## Implementation Notes

- GarageStore.migrate() needs access to CarRegistry to look up the starter van by id. CarRegistry is an autoload loaded before SaveManager/MetaManager, so it is available. The current CarRegistry.migrate() reads a hardcoded car id — preserve that constant or move it to a named constant.
- KnowledgeStore (or KnowledgeManager) orphan cleanup needs to iterate category_points keys against CategoryRegistry. Same autoload-ordering guarantee applies.
- SaveManager's manager registration: simplest approach is `register_manager(manager)` called from MetaManager._ready() and KnowledgeManager._ready(), mirroring the existing `register_section()` pattern. `run_migrations()` iterates `_managers` calling `migrate()`; `run_validation()` iterates `_managers` calling `validate()` and accumulates booleans.
- Boot order constraint: SaveManager.load() must complete before run_migrations(). Current order (SaveManager._ready() → ... → GameManager._ready() calling load then migrations) is unchanged; only the fan-out target changes from RegistryCoordinator to SaveManager.
- ResourceRegistry non-empty assert: use `assert(size() > 0, "%s registry is empty" % get_class())` or equivalent, placed after data loading completes in `_ready()`.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Fresh save with no garage data | GarageStore.migrate() inserts starter van — same behavior as current CarRegistry.migrate(), just different owner |
| Save with category keys that no longer exist in CategoryRegistry | KnowledgeStore.migrate() erases them — same behavior as current CategoryRegistry.migrate() |
| A future registry needs boot-time migration | It implements migrate() on its own store or manager — no coordinator needed; SaveManager fan-out covers managers |
| YAML has invalid cross-references (weight keys pointing to nonexistent categories) | validate_yaml.py catches it pre-build; runtime no longer checks |

## Acceptance Criteria

1. RegistryCoordinator autoload no longer exists in project.godot or the codebase.
2. Fresh saves still receive a starter van and correct initial state.
3. Old saves with orphaned category keys are cleaned up on load.
4. All registries assert non-empty at boot without external coordination.
5. validate_yaml.py catches invalid cross-registry references that LocationRegistry.validate() previously caught.
6. Game behavior is identical — no logic, math, or flow changes.
7. Standards lint passes on all changed files.
