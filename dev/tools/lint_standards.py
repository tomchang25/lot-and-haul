"""
lint_standards.py
Enforce the machine-checkable subset of dev/standards/ against source files.

This is the Tier 1 / Tier 2 layer of the standards harness (see
dev/standards/standards_enforcement.md). It does NOT try to judge genuinely
semantic rules — it either decides a rule outright (Tier 1) or checks that a
fuzzy rule has been made syntactic via a required marker (Tier 2). The
remaining judgment calls are left to the Tier 3 reviewer.

Each check cites the standard section it enforces, so this file never becomes a
second source of truth — it points back at the doc.

Usage:
    # Lint the whole tree (CI / pre-commit backstop):
    python lint_standards.py --root .

    # Lint specific files (PostToolUse hook — only what changed):
    python lint_standards.py --files game/run/auction/auction_scene.gd

Exit code is 0 when clean, 1 when any violation is found.
Stdlib only — no third-party imports, so the hook stays fast and import-safe.
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# ── Scope ──────────────────────────────────────────────────────────────────────
#
# The scene architecture standard applies to block scene scripts, testbed
# scenes, and reusable UI component scripts. It explicitly does NOT apply to
# autoloads / global managers, resource definitions under data/, or common
# framework scripts. We approximate that scope by directory.

SCANNED_DIRS = ("game", "stage")
EXCLUDED_PARTS = (".godot", "data", "global", "addons")

# ── node-src markers ─────────────────────────────────────────────────────────
#
# The permitted-exceptions vocabulary from block_scene_architecture_standard.md
# §11. A runtime add_child of a node NOT produced by .instantiate() must declare
# which exception applies via a trailing `# node-src: <tag>` comment.

VALID_NODE_SRC_TAGS = frozenset(
    {
        "instance",    # packed scene instance not auto-detected as instantiate()
        "ephemeral",   # tooltip, empty-state label, separator in a dynamic list
        "drawn",       # custom-drawn control (inner class with _draw())
        "debug",       # debug-only display behind OS.is_debug_build()
        "timer",       # Timer node (must be created in code, never in .tscn)
    }
)

NODE_SRC_RE = re.compile(r"#\s*node-src:\s*([a-z_]+)")
ADD_CHILD_RE = re.compile(r"\badd_child\(\s*([^,)]+)")
# Matched per-line (never over the whole file): `[ \t]` instead of `\s` so the
# type-hint group can't swallow the following line via a newline.
INSTANTIATE_ASSIGN_RE = re.compile(
    r"^[ \t]*(?:var[ \t]+)?(\w+)[ \t]*(?::[ \t]*[\w\[\], ]+)?:?=[ \t]*[\w.\[\]()]*\.instantiate\(\)"
)


# ── Result type ──────────────────────────────────────────────────────────────


@dataclass
class Violation:
    """A single rule violation at a specific source location."""

    path: str
    line: int
    rule: str
    section: str
    message: str

    def format(self) -> str:
        return (
            f"{self.path}:{self.line}  [{self.rule} | {self.section}]\n"
            f"    {self.message}"
        )


# ── Tier 2: Node Source Rule (block_scene_architecture_standard.md §11) ──────


def check_node_source(path: str, text: str) -> list[Violation]:
    """Every runtime add_child must add a .instantiate()'d packed scene OR carry
    a valid `# node-src: <tag>` marker declaring which permitted exception applies.

    This is the Tier-2 trick: we can't decide "is this node persistent?" by
    machine, so the convention forces the author to declare intent in a form we
    CAN check. Unmarked, non-instantiate add_child -> violation. A wrong claim
    (e.g. `# node-src: ephemeral` on a clearly persistent node) is then visible
    and greppable for the Tier-3 reviewer to judge."""
    violations: list[Violation] = []
    lines = text.splitlines()

    # Variables assigned from .instantiate() anywhere in the file are treated as
    # packed scene instances and need no marker. Matched per-line so a multiline
    # regex can't let one statement bleed into the next.
    instantiated_vars: set[str] = set()
    for ln in lines:
        am = INSTANTIATE_ASSIGN_RE.search(ln)
        if am:
            instantiated_vars.add(am.group(1))

    for i, line in enumerate(lines, start=1):
        m = ADD_CHILD_RE.search(line)
        if not m:
            continue

        arg = m.group(1).strip()
        marker = NODE_SRC_RE.search(line)
        # The marker may trail the call OR sit on the comment line directly above
        # it (preferred placement — keeps long calls and notes readable). Only the
        # immediately-preceding line is consulted, and only if it is a comment, so
        # a marker can never be borrowed from an unrelated statement.
        if not marker and i >= 2:
            prev_line = lines[i - 2]
            if prev_line.lstrip().startswith("#"):
                marker = NODE_SRC_RE.search(prev_line)

        # Allowed without a marker: inline instantiate, or a variable that was
        # assigned from .instantiate() earlier.
        if ".instantiate()" in arg:
            continue
        if arg in instantiated_vars:
            continue

        if marker:
            tag = marker.group(1)
            if tag not in VALID_NODE_SRC_TAGS:
                violations.append(
                    Violation(
                        path,
                        i,
                        "node-source",
                        "scene §11",
                        f"unknown node-src tag '{tag}'. "
                        f"Use one of: {', '.join(sorted(VALID_NODE_SRC_TAGS))}.",
                    )
                )
            continue

        # Unmarked, non-instantiate add_child: this is the candidate the rule is
        # about. The author must either move the node into the .tscn or, if it is
        # a permitted exception, declare which one with a marker.
        violations.append(
            Violation(
                path,
                i,
                "node-source",
                "scene §11",
                f"add_child({arg}) has no node-src marker. Persistent nodes "
                f"belong in the .tscn (@onready). If this is a permitted "
                f"exception, add a marker on the line directly above the call "
                f"(or trailing it), e.g. `# node-src: ephemeral`. "
                f"Tags: {', '.join(sorted(VALID_NODE_SRC_TAGS))}.",
            )
        )

    return violations


# ── Tier 1: signal connections live in code, not the .tscn (scene §Signal) ───


CONNECTION_RE = re.compile(r"^\[connection\b")


def check_tscn_connections(path: str, text: str) -> list[Violation]:
    """Signals must be connected in _ready(), not stored in the .tscn. Any
    [connection] block in a scene file is a hard violation — fully decidable,
    so this is Tier 1."""
    violations: list[Violation] = []
    for i, line in enumerate(text.splitlines(), start=1):
        if CONNECTION_RE.match(line.strip()):
            violations.append(
                Violation(
                    path,
                    i,
                    "tscn-connection",
                    "scene §Signal connections",
                    "signal connection stored in .tscn. Connect it in _ready() "
                    "instead so the full wiring surface is visible in code.",
                )
            )
    return violations


# ── Dispatch ─────────────────────────────────────────────────────────────────

# (suffix, check fn) pairs. Add new checks here as more rules graduate from the
# manifest into machine enforcement.
GD_CHECKS = (check_node_source,)
TSCN_CHECKS = (check_tscn_connections,)


def lint_file(path: Path, repo_root: Path) -> list[Violation]:
    """Run the checks that apply to a single file, by extension."""
    rel = _rel(path, repo_root)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    if path.suffix == ".gd":
        return [v for chk in GD_CHECKS for v in chk(rel, text)]
    if path.suffix == ".tscn":
        return [v for chk in TSCN_CHECKS for v in chk(rel, text)]
    return []


# ── Helpers ──────────────────────────────────────────────────────────────────


def _rel(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _in_scope(path: Path, repo_root: Path) -> bool:
    """True if the file is under a scanned dir and not an excluded subtree."""
    rel = _rel(path, repo_root)
    parts = rel.split("/")
    if parts[0] not in SCANNED_DIRS:
        return False
    return not any(part in EXCLUDED_PARTS for part in parts)


def _collect_tree(repo_root: Path) -> list[Path]:
    files: list[Path] = []
    for d in SCANNED_DIRS:
        base = repo_root / d
        if not base.is_dir():
            continue
        files.extend(base.rglob("*.gd"))
        files.extend(base.rglob("*.tscn"))
    return [f for f in files if _in_scope(f, repo_root)]


# ── CLI entry point ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Lint source files against the machine-checkable standards."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repo root. Used to resolve scope and report relative paths.",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Specific files to lint (hook mode). Out-of-scope files are skipped.",
    )
    args = parser.parse_args()

    repo_root = Path(args.root).resolve()

    if args.files:
        targets = [Path(f) for f in args.files]
        targets = [f for f in targets if _in_scope(f, repo_root) and f.is_file()]
    else:
        targets = _collect_tree(repo_root)

    violations: list[Violation] = []
    for f in sorted(set(targets)):
        violations.extend(lint_file(f, repo_root))

    if violations:
        print(f"standards: {len(violations)} violation(s)\n")
        for v in violations:
            print(v.format())
        sys.exit(1)

    print("standards: OK")


if __name__ == "__main__":
    main()
