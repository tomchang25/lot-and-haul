"""
lint_changed.py
PostToolUse hook wrapper: lint just the file an Edit/Write/MultiEdit touched.

Claude Code pipes the tool event as JSON on stdin. We pull the edited file
path, run the in-scope standards checks on that one file (lint_standards.py, in
this same dir), and if it has violations we print them to stderr and exit 2.
Exit code 2 tells Claude Code to feed stderr back into the agent's context, so
the agent self-corrects in-loop instead of the drift surviving until review.

This is the in-loop delivery mechanism for Tier 1 / Tier 2 of the standards
harness (see dev/standards/standards_enforcement.md). It deliberately lints only
the changed file, not the whole tree — so adopting the convention is
incremental: the agent is nudged on the files it actually touches, never flooded
with the whole backlog at once.

Wire it up in .claude/settings.json (see dev/tools/lint_hook.settings.json).

Exit codes:
    0  no violations (or file out of scope / not a source file / linter missing)
    2  violations found — stderr is surfaced to the agent
"""

import json
import os
import sys
from pathlib import Path

# This file lives next to lint_standards.py, so add its own dir to the path.
sys.path.insert(0, str(Path(__file__).resolve().parent))

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()

try:
    import lint_standards
except Exception:  # if the linter can't load, never block the edit
    sys.exit(0)


def _edited_path(event: dict) -> Path | None:
    tool_input = event.get("tool_input") or {}
    fp = tool_input.get("file_path") or tool_input.get("path")
    return Path(fp) if fp else None


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    path = _edited_path(event)
    if path is None or not path.exists():
        sys.exit(0)

    if not lint_standards._in_scope(path, PROJECT_DIR):
        sys.exit(0)

    violations = lint_standards.lint_file(path, PROJECT_DIR)
    if not violations:
        sys.exit(0)

    print(
        f"Standards check failed for {path.name} "
        f"({len(violations)} violation(s)) — fix before continuing:\n",
        file=sys.stderr,
    )
    for v in violations:
        print(v.format(), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
