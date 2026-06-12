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
# Two scopes, by check family:
#
# Scene-architecture / naming checks apply to block scene scripts, testbed
# scenes, and reusable UI component scripts. They explicitly do NOT apply to
# autoloads / global managers, resource definitions under data/, or common
# framework scripts. We approximate that scope by directory.
#
# The error-guard check (bare push_error ban) applies to ALL GDScript in the
# project — guards live mostly in managers and runtime types, so limiting it
# to scene dirs would make it a dead letter.

SCANNED_DIRS = ("game", "stage")
ERROR_GUARD_DIRS = ("game", "stage", "common", "global", "data")
EXCLUDED_PARTS = (".godot", "data", "global", "addons")
ERROR_GUARD_EXCLUDED_PARTS = (".godot", "addons")

# ── node-src markers ─────────────────────────────────────────────────────────
#
# The permitted-exceptions vocabulary from block_scene_architecture_standard.md
# §11. A runtime add_child of a node NOT produced by .instantiate() must declare
# which exception applies via a trailing `# node-src: <tag>` comment.

VALID_NODE_SRC_TAGS = frozenset(
    {
        "instance",  # packed scene instance not auto-detected as instantiate()
        "ephemeral",  # tooltip, empty-state label, separator in a dynamic list
        "drawn",  # custom-drawn control (inner class with _draw())
        "debug",  # debug-only display behind OS.is_debug_build()
        "timer",  # Timer node (must be created in code, never in .tscn)
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


# ── Tier 1: match wildcard rule (naming_conventions.md §11) ──────────────────

# Matches any match arm whose pattern list ends with the `_` wildcard, whether
# standalone (`    _:`) or after a comma list (`    "foo", _:`).
# `_\s*:` requires `_` followed immediately by optional space then `:`, which
# distinguishes the wildcard from identifiers like `_name` (never `_name:`).
_WILDCARD_ARM_RE = re.compile(r"^(\s+)(?:.*,\s*)?_\s*:\s*(.*?)\s*$")
_SAFE_WILDCARD_RE = re.compile(
    r"^(?:ToastManager\.show_dev_error\b|push_warning\b|pass\b|#|$)"
)


def check_match_wildcard(path: str, text: str) -> list[Violation]:
    """_: arms must contain only ToastManager.show_dev_error / push_warning,
    or be empty. Effect code belongs in explicitly-named arms so that adding a
    new value later surfaces unhandled branches rather than silently falling
    through. (naming_conventions.md §11; bare push_error is banned by the
    error-guard standard, so the unexpected-value guard is show_dev_error.)"""
    violations: list[Violation] = []
    lines = text.splitlines()
    for i, line in enumerate(lines, start=1):
        m = _WILDCARD_ARM_RE.match(line)
        if not m:
            continue
        arm_indent = len(m.group(1))
        inline = m.group(2).strip()

        # Inline code on the same line as _: — e.g. `_: x = foo()`.
        if inline and not _SAFE_WILDCARD_RE.match(inline):
            violations.append(
                Violation(
                    path,
                    i,
                    "match-wildcard",
                    "naming §11",
                    "_: arm contains effect code. Expected values belong in "
                    "explicit named arms; _: is reserved for "
                    "ToastManager.show_dev_error / push_warning.",
                )
            )
            continue

        # Multi-line body — scan lines at strictly greater indentation.
        for j in range(i, len(lines)):
            body = lines[j]
            stripped = body.strip()
            if not stripped:
                continue
            body_indent = len(body) - len(body.lstrip())
            if body_indent <= arm_indent:
                break
            if not _SAFE_WILDCARD_RE.match(stripped):
                violations.append(
                    Violation(
                        path,
                        i,
                        "match-wildcard",
                        "naming §11",
                        "_: arm contains effect code. Expected values belong in "
                        "explicit named arms; _: is reserved for push_error / "
                        "push_warning.",
                    )
                )
                break

    return violations


# ── Tier 1: bare push_error ban (error_guard_standard.md §3a) ─────────────────
#
# All error logging goes through ToastManager: show_error() for runtime guards
# (logs internally), show_dev_error() for programmer errors. A bare push_error
# at a call site is a violation, with two exceptions:
#
#   - toast_manager.gd itself — the single home of the underlying push_error.
#   - Boot-phase code that runs before the ToastManager autoload exists
#     (EventBus, SettingsStore, Debug load earlier). Tier-2 style: the author
#     declares it with a `# push-error: boot` marker trailing the call or on
#     the comment line directly above, making the claim greppable for review.

PUSH_ERROR_RE = re.compile(r"\bpush_error\s*\(")
PUSH_ERROR_BOOT_MARKER_RE = re.compile(r"#\s*push-error:\s*boot\b")
PUSH_ERROR_EXEMPT_FILES = frozenset({"global/autoloads/toast_manager.gd"})


def check_bare_push_error(path: str, text: str) -> list[Violation]:
    """Flag every bare push_error call site. Runtime guards must use
    ToastManager.show_error() (which logs internally); programmer-error guards
    must use ToastManager.show_dev_error(). Pre-ToastManager boot code may
    declare the exception with `# push-error: boot`.
    (error_guard_standard.md §3a)

    Matches preceded by `#` on the same line are skipped so commented-out code
    and doc mentions don't trip the rule. (A `#` inside a string literal before
    the call would also skip — accepted as a rare false-negative.)"""
    if path in PUSH_ERROR_EXEMPT_FILES:
        return []

    violations: list[Violation] = []
    lines = text.splitlines()
    for i, line in enumerate(lines, start=1):
        m = PUSH_ERROR_RE.search(line)
        if not m:
            continue
        hash_idx = line.find("#")
        if hash_idx != -1 and hash_idx < m.start():
            continue
        if PUSH_ERROR_BOOT_MARKER_RE.search(line):
            continue
        if i >= 2:
            prev = lines[i - 2]
            if prev.lstrip().startswith("#") and PUSH_ERROR_BOOT_MARKER_RE.search(prev):
                continue
        violations.append(
            Violation(
                path,
                i,
                "bare-push-error",
                "error-guard §3a",
                "bare push_error at call site. Runtime guards: "
                "ToastManager.show_error() (logs internally). Programmer "
                "errors: ToastManager.show_dev_error(). Code running before "
                "the ToastManager autoload loads may declare "
                "`# push-error: boot`.",
            )
        )

    return violations


# ── Dispatch ─────────────────────────────────────────────────────────────────

# Check families by scope. Add new checks here as more rules graduate from the
# manifest into machine enforcement.
GD_SCENE_CHECKS = (check_node_source, check_match_wildcard)
GD_ERROR_GUARD_CHECKS = (check_bare_push_error,)
TSCN_CHECKS = (check_tscn_connections,)


def lint_file(path: Path, repo_root: Path) -> list[Violation]:
    """Run the checks that apply to a single file, by extension and scope."""
    rel = _rel(path, repo_root)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    violations: list[Violation] = []
    if path.suffix == ".gd":
        if _in_scope(path, repo_root):
            violations.extend(v for chk in GD_SCENE_CHECKS for v in chk(rel, text))
        if _in_error_guard_scope(path, repo_root):
            violations.extend(
                v for chk in GD_ERROR_GUARD_CHECKS for v in chk(rel, text)
            )
    elif path.suffix == ".tscn" and _in_scope(path, repo_root):
        violations.extend(v for chk in TSCN_CHECKS for v in chk(rel, text))
    return violations


# ── Helpers ──────────────────────────────────────────────────────────────────


def _rel(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _in_scope(path: Path, repo_root: Path) -> bool:
    """True if the file is under a scanned dir and not an excluded subtree.
    (Scene-architecture / naming check scope.)"""
    rel = _rel(path, repo_root)
    parts = rel.split("/")
    if parts[0] not in SCANNED_DIRS:
        return False
    return not any(part in EXCLUDED_PARTS for part in parts)


def _in_error_guard_scope(path: Path, repo_root: Path) -> bool:
    """True if the file is covered by the error-guard checks (all project
    GDScript dirs)."""
    rel = _rel(path, repo_root)
    parts = rel.split("/")
    if parts[0] not in ERROR_GUARD_DIRS:
        return False
    return not any(part in ERROR_GUARD_EXCLUDED_PARTS for part in parts)


def _collect_tree(repo_root: Path) -> list[Path]:
    files: list[Path] = []
    for d in dict.fromkeys(SCANNED_DIRS + ERROR_GUARD_DIRS):
        base = repo_root / d
        if not base.is_dir():
            continue
        files.extend(base.rglob("*.gd"))
        files.extend(base.rglob("*.tscn"))
    return [
        f
        for f in files
        if _in_scope(f, repo_root) or _in_error_guard_scope(f, repo_root)
    ]


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
        targets = [
            f
            for f in targets
            if (_in_scope(f, repo_root) or _in_error_guard_scope(f, repo_root))
            and f.is_file()
        ]
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
