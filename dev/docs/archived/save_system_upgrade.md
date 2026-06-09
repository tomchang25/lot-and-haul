# Save System Upgrade

Upgrade SaveManager from a single-file write-in-place system to an append-only counter-based save with manifest, load fallback, migration alerts, and a lightweight toast overlay for player-visible notifications.

## Context

The current system writes directly to `user://save.json`. A crash or error mid-write corrupts the only copy. There is no fallback, no corruption detection beyond a parse check, and migrations run silently. The upgrade addresses three failure modes: data corruption from interrupted writes, total loss from a single bad file, and invisible schema migrations that make debugging harder.

## On-disk format

Counter-based save files: `user://save_1.json`, `user://save_2.json`, ..., `user://save_N.json`. The counter increments on every save. Files are never overwritten — each save creates a new file. Up to 10 files are retained; when the count exceeds 10, the oldest files are deleted (best-effort).

Save file payload is unchanged from the current format:

```
{
  "schema_version": 2,
  "sections": { ... }
}
```

No counter inside the file — the filename _is_ the counter. `schema_version` remains a legacy stamp (written but never checked on load).

## Manifest

A small manifest file `user://save_manifest.json` tracks the current state:

```
{
  "current_slot": 552,
  "version": 1
}
```

- `current_slot` — the counter of the most recent successful save. Used as the fast path on load (skip scanning the directory).
- `version` — manifest format version, for future-proofing the manifest itself.

**Recovery:** if the manifest is missing or corrupt, SaveManager scans `user://` for files matching `save_*.json`, parses the counter from each filename, and uses the highest. The manifest is an optimization, not a requirement.

## Save sequence

1. Determine `new_counter`: read `current_slot` from manifest (or scan filenames if manifest is unavailable) and add 1.
2. Serialize all providers to a JSON string.
3. Write the string directly to `user://save_{new_counter}.json`. If the write fails, push_error — no existing file was touched, all previous saves remain intact.
4. Update manifest: `{ "current_slot": new_counter, "version": 1 }`.
5. Best-effort cleanup: if total save file count exceeds `MAX_SAVES` (10), delete the oldest files until count equals `MAX_SAVES`. Deletion failures are non-fatal — extra files are harmless.

No existing file is ever modified or deleted during steps 1–4. A crash mid-write at step 3 leaves a corrupt `save_{new_counter}.json`, but the manifest still points to the previous counter — load goes straight to the last good file. Even without the manifest, the fallback chain skips the corrupt file. Cleanup in step 5 only targets files that are already superseded by at least 10 newer saves.

## Load sequence

1. Read manifest. If valid, set `target = current_slot`.
2. Build a candidate list: if the manifest gave a target, start with `save_{target}.json`. Regardless, scan `user://` for all `save_*.json` files, sort by counter descending.
3. For each candidate in order: parse JSON, validate structure (has `sections` key, sections is a Dictionary).
4. Feed the first structurally valid file to all providers via `from_dict()`.
5. If the loaded file was not the highest-counter file, toast a warning naming the skipped file(s) and the reason each failed. This warning shows regardless of Debug mode.
6. If no file passes validation, start fresh (no providers loaded) and toast a warning.
7. After successful load, rewrite the manifest with the counter of the file that was actually loaded (corrects any manifest drift).

File-level failures (unparseable JSON, missing `sections` key) are the fallback triggers. Store-level `from_dict()` is already resilient — it drops unknown IDs with warnings and uses `.get()` defaults — so it does not need a success/failure return.

## Legacy migration

On first boot after the upgrade, `user://save.json` (the old single file) may exist while no counter-based files do. SaveManager detects this: if no `save_*.json` exists but `save.json` does, read it, write it as `save_1.json` via the atomic path, write the manifest with `current_slot: 1`, then delete `save.json` (best-effort). This is a one-time migration.

## Migration logging

StoreBase gains a `_migration_log: Array[String]` field and a `get_migration_log() -> Array[String]` method that returns and clears the log.

Stores that override `_apply_migrations()` append human-readable descriptions to `_migration_log` for each migration branch they execute, e.g. `"EconomyStore v1→v2: renamed 'cash' to 'balance'"`.

Managers (MetaManager, KnowledgeManager) implement `get_migration_log()` by aggregating logs from all their owned stores.

SaveManager calls `get_migration_log()` on each provider after `from_dict()`. If any messages were collected and `Debug.enabled` is true, they are sent to ToastManager as info-level toasts.

## Toast notification system

New autoload: `ToastManager`, registered after `Debug` in the autoload order. Creates a high-layer CanvasLayer with a VBoxContainer anchored to the top-center of the screen. Purely code-built — no `.tscn`.

API:

- `show_warning(message: String)` — always displayed, regardless of Debug mode. Used for corruption fallback alerts.
- `show_info(message: String)` — displayed only when `Debug.enabled` is true. Used for migration alerts.

Each toast is a PanelContainer containing a Label, styled to match the project theme (dark surface, 1px border). Toasts auto-dismiss after a configurable duration (~6 seconds for warnings, ~4 seconds for info) with a fade-out tween. Multiple toasts stack vertically; older toasts shift up as new ones appear.

Color coding: warnings use `warning_yellow` text, info uses primary text color. Both use the standard panel background from the theme.

## Autoload order change

Current order around SaveManager:

```
... → SuperCategoryRegistry → SaveManager → KnowledgeManager → MetaManager → ...
```

Insert ToastManager after Debug:

```
EventBus → SettingsStore → Debug → ToastManager → AudioManager → ...
```

SaveManager, KnowledgeManager, and MetaManager remain in their current positions. SaveManager references ToastManager (which loads earlier), so the dependency is safe.

## Phases

### Phase 1 — ToastManager autoload

Create `global/autoloads/toast_manager.gd`. Register in `project.godot` after Debug. Verify it renders toasts independently of the save system.

### Phase 2 — StoreBase migration log infrastructure

Add `_migration_log` field and `get_migration_log()` to StoreBase. Add `get_migration_log()` to MetaManager and KnowledgeManager (aggregating from owned stores). No existing stores have live migrations, so this phase is pure infrastructure — nothing to log yet, but the plumbing is testable.

### Phase 3 — SaveManager rewrite

Replace the single-file save/load with the full system: counter-based filenames, manifest, append-only writes, load fallback chain, legacy `save.json` migration, best-effort cleanup, and toast wiring for both corruption warnings and migration info.

### Phase 4 — Verification

Confirm the following manually or via testbed:

- Normal save/load cycle produces counter-based files with incrementing counters.
- Manifest tracks the latest counter.
- Deliberately corrupting the latest save file triggers fallback to the next-oldest with a warning toast.
- Corrupting the manifest still loads correctly (via filename scan).
- Corrupting all save files starts fresh with a warning toast.
- Old `save.json` is migrated to `save_1.json` on first boot.
- File count stays at or below 10 after repeated saves.
- A store with a version bump (bump one store temporarily for testing) produces a migration info toast in debug mode and no toast outside debug mode.

## Acceptance criteria

- Append-only counter-based save files, never overwriting existing files.
- Manifest as fast-path for load, recoverable from filenames if corrupt.
- Direct write to final filename — no `.tmp` intermediary needed; crash safety comes from the manifest pointing to the previous good file plus the fallback chain.
- Retain up to 10 files; best-effort cleanup of oldest beyond that threshold.
- Load tries files newest-first; falls back on file-level failure.
- Corruption fallback toast visible in all modes.
- Migration detail toast visible only in debug mode.
- Legacy `save.json` auto-migrated on first boot.
- No changes to the provider interface (`to_dict`, `from_dict`, `validate`) — only additive `get_migration_log()`.

## Files touched

| File                                             | Change                                                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------- |
| `global/autoloads/toast_manager.gd`              | New — toast overlay autoload                                              |
| `common/gameplay/store/store_base.gd`            | Add `_migration_log`, `get_migration_log()`                               |
| `global/autoloads/save_manager.gd`               | Rewrite — counter-based save/load, manifest, fallback chain, toast wiring |
| `global/autoloads/managers/meta_manager.gd`      | Add `get_migration_log()` aggregation                                     |
| `global/autoloads/managers/knowledge_manager.gd` | Add `get_migration_log()` aggregation                                     |
| `project.godot`                                  | Register ToastManager autoload after Debug                                |
