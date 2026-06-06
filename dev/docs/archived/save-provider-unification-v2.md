# SaveManager Provider Unification & Legacy Cleanup

## Goal

Merge SaveManager's `_sections` and `_managers` arrays into a single `_providers` list, and remove dead legacy code paths in SaveManager and StorageStore. The current save is already schema 2 with sectioned format — the flat-save fallback, schema 1→2 migration, and research_slots migration are unreachable. Cleaning them out simplifies the codebase ahead of a proper migration-version system.

## Relational Context

- SaveManager owns `_providers` (merged from `_sections` + `_managers`). It calls `to_dict()` / `from_dict()` during save/load and `migrate()` / `validate()` during boot fan-out. It never implements these methods itself.
- MetaManager and KnowledgeManager are the only two registrants. Each calls `SaveManager.register_provider(self)` once in `_ready()`, replacing the current two-call pattern.
- GameManager calls `SaveManager.load()`, `SaveManager.run_migrations()`, `SaveManager.run_validation()` — signatures unchanged, only internal iteration target changes.
- StoreBase already defines all four methods (`to_dict`, `from_dict`, `migrate`, `validate`) as a unified interface. This change aligns SaveManager's registration model with that existing reality.
- `register_sections()` (bulk convenience) has zero external callers and is removed.
- SaveManager.load() currently handles three formats: (a) legacy flat dict with no "sections" key, (b) sectioned schema 1 (knowledge keys inside "economy"), (c) sectioned schema 2 (current). Only (c) is reachable — (a) and (b) are removed.
- StorageStore.from_dict() contains a `research_slots` migration path and a `_migrate_research_slots()` helper for pre-time-slot flat saves. The current save has no `research_slots` key — this code is unreachable and removed.
- StorageStore.from_dict() calls `entry.apply_storage_migration()` on each loaded ItemEntry — this auto-reveals surface clues on load and is **not** legacy. It stays.
- GarageStore.migrate() ensures a starter van for empty garages — this is a new-game safety net, **not** legacy. It stays.
- KnowledgeStore.migrate() prunes stale category IDs — ongoing data integrity, **not** legacy. It stays.
- `SCHEMA_VERSION` constant is kept and still written to the save file. The load path simply requires it to be 2 (or absent, defaulting to current). This preserves forward compatibility for the upcoming migration-version system.

## Scope

### Included

- Merge `_sections` and `_managers` into `_providers` in SaveManager
- Replace `register_section` + `register_sections` + `register_manager` with `register_provider`
- Update MetaManager and KnowledgeManager `_ready()` to single registration call
- Remove flat-save fallback in SaveManager.load()
- Remove schema 1→2 migration in SaveManager.load()
- Remove stale trailing comment about removed systems in SaveManager.load()
- Remove `research_slots` migration path and `_migrate_research_slots()` from StorageStore
- Update docstrings/comments in all changed files

### Excluded

- Migration version system (next task)
- Changes to StoreBase or individual Store classes (beyond StorageStore cleanup)
- Changing which object is the registrant (Managers remain the registration boundary)
- Renaming `apply_storage_migration()` on ItemEntry (active code, separate chore)

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoloads/save_manager.gd` | Medium | Merge two arrays into `_providers`, replace three registration functions with one, remove flat-save fallback and schema 1→2 migration from load(), simplify to direct sectioned dispatch |
| `global/autoloads/managers/meta_manager.gd` | Small | Replace two registration calls with one `register_provider` call |
| `global/autoloads/managers/knowledge_manager.gd` | Small | Replace two registration calls with one `register_provider` call |
| `common/gameplay/store/storage_store.gd` | Medium | Remove `research_slots` migration check in from_dict() and delete `_migrate_research_slots()` entirely, update docstring |

## Implementation Notes

- `register_provider()` asserts all four methods: `to_dict`, `from_dict`, `migrate`, `validate`. This is the union of the old asserts from both registration functions.
- SaveManager.load() after cleanup: parse JSON → require "sections" key (push_error and return if absent) → read sections_data → iterate `_providers` calling `from_dict()`. No schema version branching. `SCHEMA_VERSION` is still written on save for forward compat.
- StorageStore.from_dict() after cleanup: just the storage_items loop (with `apply_storage_migration()`) and the next_entry_id restore. The `research_slots` guard and the entire `_migrate_research_slots` method (lines 85–141) are deleted.
- StorageStore docstring on from_dict() references "migration for legacy research_slots saves" — update to reflect the simplified contract.

## Acceptance Criteria

1. SaveManager exposes exactly one registration method (`register_provider`); the three old methods are gone.
2. SaveManager holds a single `_providers` array; `_sections` and `_managers` are gone.
3. MetaManager and KnowledgeManager each call `register_provider` once in `_ready()`.
4. SaveManager.load() has no flat-save fallback and no schema 1→2 migration branch.
5. StorageStore has no `research_slots` migration code.
6. Save, load, migration, and validation behavior is unchanged for schema 2 saves.
7. Stale comments about removed systems are gone from all changed files.
