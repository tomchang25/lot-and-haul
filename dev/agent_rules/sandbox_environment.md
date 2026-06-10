# Sandbox Environment — Shell vs. File Tools

The sandboxed Linux shell can return **phantom file corruption** for files in this repo — blocks of NUL bytes, mid-token truncation, "binary file matches", or wrong byte counts — especially right after a write. This is a mount artifact, NOT real disk damage. The files are intact in VS Code and git in the real environment.

## Rules

- The Read/Edit file tools are authoritative. After modifying a file, verify it with **Read**, never by `cat`/`hexdump`/`wc`/`grep` through the shell. If Read shows clean content, the file is fine — stop.
- Never diagnose "corrupted files" from a shell read alone, and never `git restore`/overwrite working-tree files to "recover" from shell-reported corruption — that risks discarding genuine uncommitted work over a false reading.
- `git` against the object DB (`git show HEAD:<file>`, `git log`, `git diff`) is reliable; working-tree file-content reads through the shell mount are not.
