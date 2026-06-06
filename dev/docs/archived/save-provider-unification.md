# SaveManager Provider Unification

## Goal

Merge SaveManager's `_sections` and `_managers` arrays into a single `_providers` list. Both arrays hold identical objects (MetaManager, KnowledgeManager) registered through two separate calls — a legacy split with no architectural justification. Unifying them removes the false distinction and simplifies the registration API ahead of migration-version work.

## Relational Context

- SaveManager owns `_providers` (merged from `_sections` + `_managers`). It is the coordinator: it calls `to_dict()` / `from_dict()` during save/load and `migrate()` / `validate()` during boot fan-out. It never implements these methods itself.
- MetaManager and KnowledgeManager are the only two registrants. Each calls `SaveManager.register_provider(self)` once in `_ready()`, replacing the current two-call pattern (`register_section` + `register_manager`).
- GameManager calls `SaveManager.load()`, `SaveManager.run_migrations()`, `SaveManager.run_validation()` — these public methods are unchanged in signature, only their internal iteration target changes from `_sections`/`_managers` to `_providers`.
- StoreBase already defines all four methods (`to_dict`, `from_dict`, `migrate`, `validate`) as a unified interface. This change aligns SaveManager's registration model with that existing reality.
- `register_sections()` (bulk convenience) has zero external callers and is removed.

## Scope

### Included

- Merge `_sections` and `_managers` into `_providers` in SaveManager
- Replace `register_section` + `register_sections` + `register_manager` with `register_provider`
- Update MetaManager and KnowledgeManager `_ready()` to single registration call
- Update SaveManager docstring/comments

### Excluded

- Migration version system (next task)
- Schema-level migration logic in `load()` (stays as-is)
- Any changes to StoreBase or individual Store classes
- Changing which object is the registrant (Managers remain the registration boundary, not Stores directly)

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoloads/save_manager.gd` | Small | Merge two arrays into `_providers`, replace three registration functions with one, update iteration in `save`/`load`/`run_migrations`/`run_validation` |
| `global/autoloads/managers/meta_manager.gd` | Small | Replace two registration calls with one `register_provider` call |
| `global/autoloads/managers/knowledge_manager.gd` | Small | Replace two registration calls with one `register_provider` call |

## Implementation Notes

- `register_provider()` asserts all four methods: `to_dict`, `from_dict`, `migrate`, `validate`. This is the union of the old asserts from both `register_section` and `register_manager`.
- The file header comment in `save_manager.gd` references `register_section()` and `register_manager()` — update to reflect the new single-method API.
- `save()` and `load()` currently iterate `_sections`; `run_migrations()` and `run_validation()` iterate `_managers`. All four switch to `_providers`.

## Acceptance Criteria

1. SaveManager exposes exactly one registration method (`register_provider`); the three old methods are gone.
2. SaveManager holds a single `_providers` array; `_sections` and `_managers` are gone.
3. MetaManager and KnowledgeManager each call `register_provider` once in `_ready()`.
4. Save, load, migration, and validation behavior is unchanged.
