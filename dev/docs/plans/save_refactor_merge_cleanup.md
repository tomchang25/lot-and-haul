# Save Refactor Merge Cleanup

Pre-merge housekeeping for PR #111 (save-refactor → main). All items are mechanical — no design decisions.

Status: Plan

---

## Items

### 1. Simplify `from_dict()` type casts

Replace the verbose `if data.has(key) and data[key] is float: field = int(data[key])` pattern with direct `field = int(data.get(key, default))` across all 6 persisting stores. The `is float` guards are unnecessary — Godot's JSON always returns numbers as float, and `int()` handles the cast safely.

### 2. Split agent rules out of CLAUDE.md

Extract agent-specific instructions (sandbox mount notes, "don't diagnose corrupted files", commit format reference, lint hook reminder) into a dedicated `dev/agent_rules/` folder. CLAUDE.md stays project-description-only so it's readable by humans and agents alike. Each rule file is a self-contained markdown doc.

### 3. Classify registries.md and standards_enforcement.md

Review `dev/standards/registries.md` and `dev/standards/standards_enforcement.md` — decide whether each belongs under `dev/agent_rules/`, `dev/standards/`, or `dev/skills/`. Registries.md defines a contract (standard). Standards_enforcement.md tells agents what to lint (agent rule). Move accordingly.

### 4. Squash changelog

Consolidate the multi-section per-commit changelog entries into a single entry suitable for the squash-merge commit. One heading, concise bullet list of what changed.

### 5. Clear archived plans

Delete all `dev/docs/archived/*.md` files added during this branch. They served as intermediate reasoning artifacts; git history preserves them. The folder should be empty (or removed) on merge.

### 6. Update CLAUDE.md

Refresh to reflect post-refactor state: autoload order (`autoloads/` plural folder), folder structure (archetype subfolders under `common/gameplay/`), Store/Manager ownership model, schema_version comment (legacy stamp — per-store `_store_version` handles migrations). Remove any stale references to save sections, RegistryCoordinator, or Owner pattern.
