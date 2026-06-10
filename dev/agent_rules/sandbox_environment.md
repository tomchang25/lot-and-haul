# Sandbox Environment — Shell vs. File Tools

The sandboxed Linux shell can return **phantom file corruption** for files in this repo — blocks of NUL bytes, mid-token truncation, "binary file matches", or wrong byte counts — especially right after a write. This is a mount artifact, NOT real disk damage. The files are intact in VS Code and git in the real environment.

## Verified findings (2026-06-10)

- The dominant failure mode is **tail truncation**: the mount serves a file with its last bytes missing, cut at the byte level — mid-token (`@export var tier: i`) or even mid-UTF-8-character. Observed on 33 recently-modified files at once (verified by comparing `wc -c` through the mount against `git cat-file -s :<file>`).
- Stale views are **sticky**: waiting, re-reading, and even re-writing the file from the Windows side did not refresh the mount's truncated view.
- `git diff`/`git status` read the **working tree through the mount**, so they report phantom diffs (e.g. spurious `\ No newline at end of file`). Only index/object-DB reads are trustworthy: `git show :<file>`, `git cat-file`, `git checkout-index`.
- The `.git/` directory desyncs too: a phantom `index.lock` returned EEXIST to git while not existing on the Windows side, with `ls`/`stat`/`rm` mutually inconsistent. This is why git mutations are forbidden — see `git_operations.md`.
- Right after the **user** runs git on the Windows side, even `.git/index` reads through the mount can be garbled (`fatal: unknown index entry format 0x…`). Object-DB reads (`git show HEAD:<file>`) stay reliable; index-based commands (`git show :<file>`, `checkout-index`, `status`) may fail transiently — report and retry later instead of attempting repairs.
- Consequence for testing: **never run the Godot headless binary against the mounted working tree** — it reads the truncated views and reports bogus parse errors (e.g. `Could not find type "i"`). See `godot_headless_check.md` for the safe procedure.

## Rules

- The Read/Edit file tools are authoritative. After modifying a file, verify it with **Read**, never by `cat`/`hexdump`/`wc`/`grep` through the shell. If Read shows clean content, the file is fine — stop.
- Never diagnose "corrupted files" from a shell read alone, and never `git restore`/overwrite working-tree files to "recover" from shell-reported corruption — that risks discarding genuine uncommitted work over a false reading.
- `git` against the object DB (`git show HEAD:<file>`, `git log`, `git show :<file>`, `git cat-file`) is reliable; working-tree file-content reads through the shell mount are not — including the working-tree side of `git diff`.
- To check whether the mount is serving a truncated view of a file: compare `wc -c <file>` against `git cat-file -s :<file>`. Mount smaller than index ⇒ truncated view (the index is LF-normalized, so the working tree should never be smaller).
- Any error found by a shell-side tool (linter, Godot, python) must be cross-checked against the Windows side (Read/Grep file tools) before being reported as real.
