# Store Versioned Migrations

## Goal

Replace the current `migrate()` fan-out (SaveManager → Manager → Store) with a per-store versioned migration system. Each store tracks its own `_version` in its save payload, and `from_dict()` calls a private `_apply_migrations()` to transform old data shapes before field restoration. The existing `migrate()` bodies in GarageStore and KnowledgeStore are legacy and removed outright, along with dead code they leave behind.

## Relational Context

- StoreBase defines the standard interface. `_apply_migrations(data: Dictionary, from_version: int) -> Dictionary` is added as a virtual method (default returns data unchanged). `_store_version() -> int` is added (default returns 1). `migrate()` is removed.
- StoreBase.from_dict() is a no-op override point — it does NOT call `_apply_migrations()` itself. Each persisting store's `from_dict()` reads `_version` from data, calls `_apply_migrations()`, then restores fields. Session-scoped stores (RunStore, LotStore) never override `from_dict()` and are unaffected.
- StoreBase.to_dict() is also a no-op override point. Each persisting store's `to_dict()` writes `"_version": _store_version()` into its payload. StoreBase does not inject it.
- SaveManager owns `run_migrations()` and the `migrate` assert in `register_provider()` — both are removed. SaveManager no longer participates in migration; it just dispatches `from_dict()` during `load()`.
- GameManager calls `SaveManager.run_migrations()` after `load()` — this call is removed. Boot becomes `load()` → `run_validation()`.
- MetaManager.migrate() is a pure fan-out to six stores — removed entirely. MetaManager retains `validate()` (still needed).
- KnowledgeManager.migrate() is a fan-out to `_knowledge.migrate()` — removed. KnowledgeManager retains `validate()`.
- GarageStore.migrate() (starter van guarantee) is legacy — removed.
- KnowledgeStore.migrate() (prune stale categories) is legacy — removed. `erase_points()` on KnowledgeStore and `erase_category_points()` on KnowledgeManager become dead code and are removed.
- KnowledgeStore.from_dict() has a `skill_levels` legacy branch (lines 104–108) and stale docstring about "legacy flat saves" — both removed.
- StorageStore.from_dict() calls `entry.apply_storage_migration()` — this is NOT migration, it's an active load-time invariant. It stays untouched.

## Scope

### Included

- Add `_store_version()` and `_apply_migrations()` to StoreBase
- Remove `migrate()` from StoreBase
- Remove `migrate()` from GarageStore, KnowledgeStore
- Remove `migrate()` fan-out from MetaManager, KnowledgeManager
- Remove `run_migrations()` and `migrate` assert from SaveManager
- Remove `run_migrations()` call from GameManager
- Remove dead `erase_points()` from KnowledgeStore and `erase_category_points()` from KnowledgeManager
- Remove `skill_levels` legacy branch from KnowledgeStore.from_dict()
- Wire `_version` read/write into each persisting store's `from_dict()` / `to_dict()`

### Excluded

- Writing actual versioned migrations (no store needs one yet — all start at version 1)
- Renaming `apply_storage_migration()` on ItemEntry
- Changes to `validate()` on any store or manager

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/store/store_base.gd` | Small | Remove `migrate()`, add `_store_version() -> int` and `_apply_migrations(data, from_version) -> Dictionary` |
| `common/gameplay/store/garage_store.gd` | Small | Remove `migrate()`, add `_version` to `to_dict()`, read version + call `_apply_migrations()` in `from_dict()` |
| `common/gameplay/store/knowledge_store.gd` | Medium | Remove `migrate()`, remove `erase_points()`, remove `skill_levels` branch in `from_dict()`, add version wiring, update docstring |
| `common/gameplay/store/storage_store.gd` | Small | Add `_version` to `to_dict()`, read version + call `_apply_migrations()` in `from_dict()` |
| `common/gameplay/store/economy_store.gd` | Small | Add version wiring to `to_dict()` / `from_dict()` |
| `common/gameplay/store/slot_store.gd` | Small | Add version wiring to `to_dict()` / `from_dict()` |
| `common/gameplay/store/progress_store.gd` | Small | Add version wiring to `to_dict()` / `from_dict()` |
| `common/gameplay/store/customers_store.gd` | Small | Add version wiring to `to_dict()` / `from_dict()` |
| `global/autoloads/save_manager.gd` | Small | Remove `run_migrations()`, remove `migrate` assert from `register_provider()` |
| `global/autoloads/managers/meta_manager.gd` | Small | Remove `migrate()` |
| `global/autoloads/managers/knowledge_manager.gd` | Small | Remove `migrate()`, remove `erase_category_points()` |
| `global/autoloads/game_manager/game_manager.gd` | Small | Remove `SaveManager.run_migrations()` call |

## Implementation Notes

- StoreBase adds two methods. `_store_version() -> int` returns 1. `_apply_migrations(data: Dictionary, from_version: int) -> Dictionary` returns `data` unchanged. Both are meant to be overridden by subclasses when they need a real migration in the future. The docstring on `_apply_migrations()` should include a concrete usage example so implementors know the pattern without looking elsewhere:
  ```gdscript
  ## Transforms saved data from [param from_version] to the current store version.
  ## Override in subclasses to handle schema changes. Migrations chain sequentially:
  ##
  ##   func _apply_migrations(data: Dictionary, from_version: int) -> Dictionary:
  ##       if from_version < 2:
  ##           data["new_field"] = data.get("old_field", 0)
  ##           data.erase("old_field")
  ##       if from_version < 3:
  ##           data["renamed"] = data.get("legacy_name", "")
  ##           data.erase("legacy_name")
  ##       return data
  ##
  ## Each block transforms data one version forward. The caller (from_dict) handles
  ## reading _version from the payload and passing it here. Returns the dict with
  ## all fields in the current version's shape, ready for field restoration.
  func _apply_migrations(data: Dictionary, _from_version: int) -> Dictionary:
      return data
  ```
- The version wiring pattern in each persisting store's `from_dict()`:
  ```
  var version: int = int(data.get("_version", 1))
  data = _apply_migrations(data, version)
  # ... existing field restoration ...
  ```
  And in `to_dict()`, add `"_version": _store_version()` to the returned dict.
- Saves without `_version` (all current saves) default to version 1 via `data.get("_version", 1)`. Since no store overrides `_apply_migrations()` yet, this is a no-op — existing saves load identically.
- KnowledgeStore.from_dict(): remove the `elif data.has("skill_levels")` branch and the trailing `else` — just let `_attribute_levels` keep its default empty dict if the key is absent. Update the docstring to remove references to legacy flat saves and skill_levels migration.
- SaveManager.register_provider() keeps asserts for `to_dict`, `from_dict`, `validate` — only the `migrate` assert is dropped.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Save file has no `_version` key in a section | `data.get("_version", 1)` defaults to 1 — treated as version 1, `_apply_migrations()` runs from version 1 (currently no-op) |
| New game with no save file | `from_dict()` never called, stores use field defaults, `to_dict()` writes version 1 on first save |

## Acceptance Criteria

1. StoreBase has `_store_version()` and `_apply_migrations()` but no `migrate()`.
2. No `migrate()` method exists on any store, manager, or SaveManager.
3. `run_migrations()` is gone from SaveManager and GameManager boot sequence.
4. Every persisting store writes `_version` in `to_dict()` and reads it in `from_dict()`.
5. `erase_points()` and `erase_category_points()` are gone.
6. `skill_levels` legacy branch is gone from KnowledgeStore.from_dict().
7. Existing saves (without `_version` key) load identically — no behavioral change.
