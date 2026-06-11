# Storage Restore: Silent-Drop Hardening (Compact Implementation Note)

Small bounded change — no cross-system redesign. Coordinates below are as-found at time of writing.

## Goal

Item entries that fail to restore from a save currently vanish silently in release builds. Surface every restore-time data loss to the player through one aggregated warning toast, remove the dead legacy branch in `ItemEntry.from_dict()`, and fold the remaining unversioned shape-sniffing migrations into `StorageStore`'s version ladder.

## Context (as found)

- `ItemEntry.from_dict()` legacy `item_id` branch (`common/gameplay/instance/item_entry.gd` L563-569) is dead code: its only call site is `storage_store.gd` L79, which runs after `StorageStore._apply_migrations()` (v<2 branch, L91-117) has already rewritten every legacy dict to composition form, and `ItemEntry.to_dict()` always writes an `anchor_id` key (L529). The branch is unreachable.
- Three silent data-loss paths: entry dropped on unresolved `item_id` during migration (`storage_store.gd` L102, `push_warning` only — debug console, invisible in release); anchor lookup miss (`item_entry.gd` L551, no warning at all — entry kept with `anchor = null`, value 0); clue lookup miss (`item_entry.gd` L553-559, nulls skipped, no record).
- Unversioned sniffing migrations still live inside `ItemEntry.from_dict()`: `anchor_revealed`/`inspected` → `unveiled` (L572-574) and `verified` bool → `reveal_all_hidden()` (L609-610). Both keys were only ever written by pre-composition (v1) saves — current `to_dict()` writes neither — so they belong in the existing v<2 branch of `StorageStore._apply_migrations()`, no version bump to 3 needed.
- Surfacing channel already exists: `StoreBase._migration_log` → manager `get_migration_log()` aggregation (`meta_manager.gd` L58-65) → `SaveManager._collect_migration_logs()` (L355-361) → `ToastManager.show_info` (debug-only). `ToastManager.show_warning` is always visible and its docstring already designates it for corruption alerts; `SaveManager.load()` already toasts warnings at boot (L177), so boot-time toast timing is proven.
- Stale revealed-clue-id stripping (`item_entry.gd` L588-598) is data-drift hygiene, not shape migration — stays where it is, out of scope.

## Changes

| File                                              | Size   | Purpose                                                                                                                                                                                |
| ------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `common/gameplay/store/store_base.gd`             | Small  | Add `_restore_warnings: Array[String]` + `get_restore_warnings()` mirroring the migration-log pattern (returns and clears).                                                             |
| `common/gameplay/instance/item_entry.gd`          | Medium | Delete legacy `item_id` branch and the two sniffing migrations; return `null` (drop) when the anchor cannot be resolved; report per-entry resolution issues via a collector parameter.  |
| `common/gameplay/store/storage_store.gd`          | Medium | Move sniffing migrations into the v<2 branch; count drops and degraded entries during `from_dict()`; append one summary line to `_restore_warnings`.                                    |
| `global/autoloads/managers/meta_manager.gd`       | Small  | Aggregate `get_restore_warnings()` across owned stores, same shape as `get_migration_log()` (L58-65).                                                                                   |
| `global/autoloads/managers/knowledge_manager.gd`  | Small  | Same aggregation passthrough as meta_manager (L90-93).                                                                                                                                  |
| `global/autoloads/save_manager.gd`                | Small  | Extend `_collect_migration_logs()`: route `get_restore_warnings()` messages to `ToastManager.show_warning` (always visible), migration log stays on `show_info`.                        |

## Implementation Notes

- `ItemEntry.from_dict(d, issues: Array = [])`: append a short string per resolution failure (anchor miss, each clue miss). Anchor miss also returns `null` — a kept entry with `anchor = null` is silent corruption (value 0, weight 0), worse than a counted drop. Clue misses keep the entry but mark it degraded.
- `StorageStore.from_dict()`: count `null` returns (dropped) and entries whose `issues` array is non-empty (degraded); migration-time `item_id` drops (L102 path) join the dropped count. If either count > 0, append one line, e.g. `"Storage: N item(s) could not be restored, M restored with missing data"`. Per-entry detail remains `push_warning` for the debug console — the toast is the aggregate only.
- v<2 branch additions, all at dict level before entry construction: `unveiled = unveiled or anchor_revealed or inspected`; if `verified` is true, union `hidden_ids` into `revealed_clue_ids`; erase the three legacy keys after translating.
- `ItemEntry.from_dict()` keeps handling the `unveiled` key only (current shape); the `anchor_revealed`/`inspected`/`verified` reads leave with the moved migrations.
- Update the stale docstring on `StorageStore.from_dict()` (L68-70) which documents the old `push_warning`-in-`ItemEntry` behavior. Do not strip other existing comments (project rule).
- `_get_anchor()`/`_get_surface_clues()` item_data fallbacks and `ItemEntry.create()` are runtime Phase-1 legacy, not save-path — untouched here.
- `CustomersStore`/`CustomerEntry` restore hardening: out of scope, same pattern can be applied later if needed.

## Edge Cases

| Case                                                          | Expected Handling                                                              |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| v1 save, `item_id` resolvable                                 | Migrated to composition in v<2 branch, loads normally (existing behavior)       |
| v1 save, `item_id` unresolvable                               | Dropped in migration, counted, aggregated warning toast                         |
| v2 save, `anchor_id` unresolvable                             | Entry dropped (was: kept as value-0 corruption), counted, warning toast         |
| v2 save, some clue ids unresolvable                           | Entry kept, degraded count, warning toast                                       |
| v1 save with `verified: true`                                 | `hidden_ids` unioned into `revealed_clue_ids` at dict level — same end state    |
| Clean load                                                    | No toast, `_restore_warnings` empty                                             |
| Debug build                                                   | Aggregate warning toast + existing per-entry `push_warning` + migration info    |

## Acceptance Criteria

1. A release-build load that loses or degrades any storage item shows a visible warning toast naming the counts; a clean load shows nothing.
2. Loading a v1 save produces identical end state to before the change (unveiled/verified translation preserved), with the migration handled entirely in the store version ladder.
3. `ItemEntry.from_dict()` contains no `item_id` handling and no version-conditional key sniffing; it parses the current shape only.
4. An entry whose anchor cannot be resolved no longer enters storage as a zero-value item.
