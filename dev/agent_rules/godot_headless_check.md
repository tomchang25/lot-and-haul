# Godot Headless Check — Safe Procedure

Running `Godot --headless` directly against the mounted working tree is **forbidden**: the mount serves tail-truncated views of recently-modified files (see `sandbox_environment.md`), so Godot reports bogus parse errors that don't exist in the real files. Verified example: a truncated `anchor_data.gd` ending at `@export var tier: i` produced `Parse Error: Could not find type "i"`.

## Procedure (verified working)

Materialize a clean snapshot from the git index into a sandbox-local directory and run there. Index/object-DB reads bypass the mount's unreliable working-tree reads.

```bash
cd <repo mount>
rm -rf /tmp/lh && mkdir -p /tmp/lh
git checkout-index -a --prefix=/tmp/lh/          # clean snapshot of STAGED content
cp -r dev/tools/bin /tmp/lh/dev/tools/           # godot binary is gitignored
cd /tmp/lh
pip install pyyaml --break-system-packages -q 2>/dev/null   # once per sandbox session
python3 dev/tools/yaml_to_tres.py --godot-root /tmp/lh       # regenerate data/tres/ (gitignored) from tracked YAML
rm -rf .godot                                    # always import fresh — stale caches poison UID resolution
timeout 40 dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path /tmp/lh --import
timeout 35 dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path /tmp/lh --quit 2>&1 | grep -E "SCRIPT ERROR|Parse"
```

## Caveats

- If `checkout-index` fails with `unknown index entry format`, the mount is serving a stale `.git/index` (typically right after the user ran git on the Windows side). Don't attempt repairs — wait and retry, or ask the user to confirm git is idle.
- **The snapshot is the INDEX, not the working tree.** Unstaged edits are absent. If results must reflect latest edits, ask the user to `git add` first; otherwise state clearly that the check ran against staged content.
- `*.uid` files and `default_bus_layout.tres` are tracked (since 2026-06-10) and come along with checkout-index. If UID errors appear (`Unrecognized UID`, `Failed to instantiate an autoload`), the cause is a stale `.godot/` from an import that ran before the `.uid` files were in place — `rm -rf .godot` and re-import.
- `assets/` and `addons/` are gitignored ⇒ missing-texture/resource warnings in /tmp runs are expected noise, not findings.
- Single-script checks (`--check-only -s <file>`) outside `--path /tmp/lh` collide with the project's `class_name` registrations and report spurious "hides a global script class" errors — always run with `--path /tmp/lh`.
- Any SCRIPT ERROR found in /tmp must be cross-checked against the Windows side (Read/Grep file tools) before being reported as a real bug.
