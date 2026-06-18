# Save Migrations

Save files live on player disks. Code that parses old save formats is **not dead code**, even when nothing in the codebase produces that format anymore — that is precisely what a migration is.

## Never delete

- `_apply_migrations()` version blocks (`if from_version < N:`) — these are **append-only**. Old blocks stay forever. Removing one means any save at that version silently corrupts or drops data on load.
- Legacy-key sniffing in `from_dict()` / migrations (`d.get("old_key", ...)`, `d.erase("old_key")`) — the keys no longer exist in the codebase by design; that's not a cleanup target.
- Always-run idempotent migrations (e.g. `ItemEntry.apply_storage_migration()`) — "migration" in the name does not mean legacy.
- Defensive `d.has(...)` / fallback-default reads in `from_dict()` — they exist for saves written before the field did.

Deleting or simplifying any of the above requires explicit user sign-off, and is normally only done at a declared save-compat break (announced major/minor version boundary). If you think a migration is truly unreachable, stop and ask — do not decide yourself.

## When refactoring a serialized type

If you rename, remove, restructure, or re-interpret any field that appears in `to_dict()` / `from_dict()`:

1. Bump `_store_version()` by 1.
2. Append a new `if from_version < N:` block to `_apply_migrations()` that rewrites the old payload into the new shape. Migrate the **data**, don't branch in the runtime code.
3. Old blocks above it stay untouched — migrations chain: v1 → v2 → v3.
4. Log via `ctx.info()` (per-entry detail) / `ctx.warn()` (summary when data is dropped or degraded). Dropping an entry must never be silent.
5. If a migration needs something being refactored away (a registry lookup, a deprecated type), do **not** stub it out (`var x = null`) — that turns the migration into a silent data-drop. Stop and ask: keep a minimal legacy lookup, snapshot the needed data into the migration, or get explicit sign-off to accept the loss.
6. Stamp `data["_version"] = _store_version()` as the final line of `_apply_migrations()`, outside every `if from_version < N:` block. Without the stamp, a re-run of `from_dict` on the same dict (e.g. anything that re-enters the load path) re-applies earlier migrations: a v1 `current_slot: 4` migrates to 3 on the first pass and to 2 on the second. The stamp makes the function re-entry-safe.

Per-store rules: migrations run inside each store's `from_dict()` via `_apply_migrations()`. There is no top-level migration pass, and the save file's `schema_version` is a legacy stamp — written, never checked. Don't build logic on it.
