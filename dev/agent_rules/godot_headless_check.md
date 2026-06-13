# Godot Headless Check — Safe Procedure

Running `Godot --headless` directly against the mounted working tree is **forbidden**: the mount serves tail-truncated views of recently-modified files (see `sandbox_environment.md`), so Godot reports bogus parse errors that don't exist in the real files. Verified example: a truncated `anchor_data.gd` ending at `@export var tier: i` produced `Parse Error: Could not find type "i"`.

## Procedure (verified working)

Materialize a clean snapshot from the git index into a sandbox-local directory and run there. Index/object-DB reads bypass the mount's unreliable working-tree reads.

```bash
cd <repo mount>
LH=$(mktemp -d /tmp/lh.XXXXXX)                   # ALWAYS a fresh random dir — never reuse /tmp/lh or rm someone else's
echo "$LH"                                        # remember this path; shell calls don't share env, so reuse it literally
git checkout-index -a --prefix="$LH/"            # clean snapshot of STAGED content
cp -r dev/tools/bin "$LH/dev/tools/"             # godot binary is gitignored
cd "$LH"
pip install pyyaml --break-system-packages -q 2>/dev/null   # once per sandbox session
python3 dev/tools/yaml_to_tres.py --godot-root "$LH"         # regenerate data/tres/ (gitignored) from tracked YAML
# SFX rendering reads script UIDs from .gd.uid sidecar files (tracked by git),
# NOT from .godot/uid_cache.bin — so it runs BEFORE --import.
python3 dev/tools/render_sfx.py --dir "$LH/data/yaml/sfx/" --godot-root "$LH"
rm -rf .godot                                    # always import fresh — stale caches poison UID resolution
timeout 90 dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path "$LH" --import
timeout 35 dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path "$LH" --quit 2>&1 | grep -E "SCRIPT ERROR|Parse"
```

Multiple agents/sessions share `/tmp`, and files created by another session's user are not removable (`Permission denied`). That is why a fixed path like `/tmp/lh` is forbidden: `mktemp -d` guarantees a private dir. Don't bother cleaning up other sessions' leftovers — just ignore them.

## Caveats

- If `checkout-index` fails with `unknown index entry format`, the mount is serving a stale `.git/index` (typically right after the user ran git on the Windows side). Don't attempt repairs — wait and retry, or ask the user to confirm git is idle.
- If retries keep failing (the garbled format bytes differ on every read), fall back to `git archive HEAD | tar -x -C "$LH"` — object-DB reads are unaffected by the stale index, so this reliably succeeds (verified 2026-06-13). The snapshot is then **HEAD, not the index**: staged-but-uncommitted changes are absent. State clearly that the check ran against HEAD when reporting results.
- **The snapshot is the INDEX, not the working tree.** Unstaged edits are absent. If results must reflect latest edits, ask the user to `git add` first; otherwise state clearly that the check ran against staged content.
- `*.uid` files and `default_bus_layout.tres` are tracked (since 2026-06-10) and come along with checkout-index. If UID errors appear (`Unrecognized UID`, `Failed to instantiate an autoload`), the cause is a stale `.godot/` from an import that ran before the `.uid` files were in place — `rm -rf .godot` and re-import.
- `assets/` and `addons/` are gitignored ⇒ missing-texture/resource warnings in /tmp runs are expected noise, not findings.
- Single-script checks (`--check-only -s <file>`) outside `--path "$LH"` collide with the project's `class_name` registrations and report spurious "hides a global script class" errors — always run with `--path "$LH"`.
- Any SCRIPT ERROR found in /tmp must be cross-checked against the Windows side (Read/Grep file tools) before being reported as a real bug.
