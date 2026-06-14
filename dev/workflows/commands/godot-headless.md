# godot-headless — safe Godot headless check

Run the safe Godot headless parser/import check by following the authoritative procedure in `dev/agent_rules/godot_headless_check.md`.

## Required Reading

Before executing, read:

- `dev/agent_rules/sandbox_environment.md`
- `dev/agent_rules/git_operations.md`
- `dev/agent_rules/godot_headless_check.md`

## Guardrails

- Treat git as read-only. Do not stage, commit, restore, reset, stash, switch/checkout branches, or otherwise mutate repo state. The only permitted checkout command is `git checkout-index`, and only when used exactly for the documented `/tmp` snapshot.
- Never run Godot directly against the mounted working tree.
- If the requested check must include unstaged edits, stop and ask the user to stage them on the Windows side. Do not run `git add`.

## Execution

Follow `dev/agent_rules/godot_headless_check.md` as the source of truth for snapshot creation, generated data, SFX rendering, fresh import, parser check, fallback, caveats, and error cross-checking. Do not copy or improvise the command sequence here; if the rule changes, this command follows it.

When reporting results, include:

- Whether the snapshot came from the index or the HEAD fallback.
- That unstaged working-tree edits are absent from an index snapshot.
- Any script/parse errors only after cross-checking them against the real repo files.
- Expected missing `assets/` or `addons/` noise only if relevant.

$ARGUMENTS
