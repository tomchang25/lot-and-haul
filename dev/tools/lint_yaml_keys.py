"""
lint_yaml_keys.py — Check/fix localization key naming conventions in YAML files.

Verifies that localization key fields (display_name_key, known_text_key,
description_key) follow the expected pattern <PREFIX>_<UPPERCASE_ID> and
auto-fixes mismatches with --fix. Comments and formatting are preserved.

Usage:
    python dev/tools/lint_yaml_keys.py              # check-only (exit 1 if violations)
    python dev/tools/lint_yaml_keys.py --fix         # auto-fix violations in place
    python dev/tools/lint_yaml_keys.py --fix --files data/yaml/affixes.yaml  # specific files

Exit code is 0 when clean, 1 when violations found.
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

YAML_DIR = Path("data/yaml")
PROJECT_ROOT = Path(".").resolve()

# ── Per-file rules ────────────────────────────────────────────────────────
# (section, id_field, key_field, key_prefix, suffix)
# suffix is appended to the key value (e.g. "_DESC" for description keys)
RULES_BY_FILE: dict[str, list[tuple[str, str, str, str, str]]] = {
    "clues.yaml": [
        ("anchors", "anchor_id", "known_text_key", "ANCHOR", ""),
        ("clues", "clue_id", "known_text_key", "CLUE", ""),
    ],
    "affixes.yaml": [
        ("affixes", "affix_id", "display_name_key", "AFFIX", ""),
    ],
    "category_data.yaml": [
        ("super_categories", "super_category_id", "display_name_key", "CAT", ""),
        ("categories", "category_id", "display_name_key", "CAT", ""),
    ],
    "location_data.yaml": [
        ("locations", "location_id", "display_name_key", "LOC", ""),
        ("locations", "location_id", "description_key", "LOC", "_DESC"),
    ],
    "commodity_data.yaml": [
        ("commodities", "commodity_id", "display_name_key", "CMD", ""),
    ],
    "perk_data.yaml": [
        ("perks", "perk_id", "display_name_key", "PERK", ""),
        ("perks", "perk_id", "description_key", "PERK", "_DESC"),
    ],
    "_test_item_generator.yaml": [
        ("super_categories", "super_category_id", "display_name_key", "CAT", ""),
        ("categories", "category_id", "display_name_key", "CAT", ""),
        ("anchors", "anchor_id", "known_text_key", "ANCHOR", ""),
        ("clues", "clue_id", "known_text_key", "CLUE", ""),
        ("affixes", "affix_id", "display_name_key", "AFFIX", ""),
    ],
    "tutorial_data.yaml": [
        ("anchors", "anchor_id", "known_text_key", "ANCHOR", ""),
        ("clues", "clue_id", "known_text_key", "CLUE", ""),
        ("affixes", "affix_id", "display_name_key", "AFFIX", ""),
    ],
}

# ── Result type ────────────────────────────────────────────────────────────


@dataclass
class Violation:
    path: str
    line: int
    field: str
    expected: str
    actual: str

    def format(self) -> str:
        return (
            f"{self.path}:{self.line}  [yaml-key]\n"
            f"    expected '{self.field}: {self.expected}', "
            f"got '{self.field}: {self.actual}'"
        )


# ── Helpers ────────────────────────────────────────────────────────────────


def to_ss(name: str) -> str:
    return name.upper().replace("-", "_")


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


# ── Section-aware line helpers ────────────────────────────────────────────


def _section_range(lines: list[str], section_name: str) -> tuple[int, int]:
    """Find the line range [start, end) of a top-level YAML section.
    Section starts at a line like 'section_name:' (no leading space).
    Ends at next top-level key or EOF. Returns (-1, -1) if not found."""
    start = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped == f"{section_name}:":
            start = i
            break
    if start == -1:
        return (-1, -1)

    end = len(lines)
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*:\s*(\S|$)", stripped):
            if not lines[i][0].isspace() and ":" in stripped:
                if not stripped.startswith(f"{section_name}:"):
                    end = i
                    break
    return (start, end)


def _find_entry_id_line(
    lines: list[str], section_start: int, section_end: int, id_field: str, id_val: str
) -> int:
    """Find the line within [section_start, section_end) that contains the id,
    e.g. 'affix_id: bag_rustic'. Returns -1 if not found."""
    for i in range(section_start, section_end):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        pattern = rf"^\s*-?\s*{re.escape(id_field)}:\s*{re.escape(id_val)}\s*(#.*)?$"
        if re.match(pattern, stripped):
            return i
    return -1


def _find_key_line(lines: list[str], id_line: int, field: str) -> int:
    """After the entry at id_line, find the first line with the key field.
    Returns -1 if not found."""
    for j in range(id_line + 1, len(lines)):
        stripped = lines[j].strip()
        if stripped.startswith(f"{field}:"):
            return j
        if stripped.startswith("- ") and j > id_line:
            break
    return -1


# ── Check ─────────────────────────────────────────────────────────────────


def _check_section(
    path: str,
    lines: list[str],
    section: str,
    id_field: str,
    key_field: str,
    key_prefix: str,
    suffix: str,
) -> list[Violation]:
    violations: list[Violation] = []
    sec_start, sec_end = _section_range(lines, section)
    if sec_start < 0:
        return violations

    raw = "".join(lines)
    data = yaml.safe_load(raw) or {}
    entries = data.get(section, []) or []

    for entry in entries:
        eid = entry.get(id_field, "")
        if not eid:
            continue
        expected = f"{key_prefix}_{to_ss(eid)}{suffix}"
        actual = entry.get(key_field, "")
        if actual == expected:
            continue

        id_line = _find_entry_id_line(lines, sec_start, sec_end, id_field, eid)
        if id_line < 0:
            continue
        key_line = _find_key_line(lines, id_line, key_field)
        if key_line < 0:
            continue

        violations.append(
            Violation(
                path=path,
                line=key_line + 1,
                field=key_field,
                expected=expected,
                actual=actual if actual else "(missing)",
            )
        )

    return violations


def lint_file(path: Path) -> list[Violation]:
    """Check all key naming conventions in a YAML file."""
    rel_path = _rel(path)
    fname = path.name
    rules = RULES_BY_FILE.get(fname)
    if not rules:
        return []

    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    lines = text.splitlines(keepends=True)
    violations: list[Violation] = []
    for rule in rules:
        violations.extend(_check_section(rel_path, lines, *rule))
    return violations


# ── Fix ───────────────────────────────────────────────────────────────────


def _fix_section(
    lines: list[str],
    section: str,
    id_field: str,
    key_field: str,
    key_prefix: str,
    suffix: str,
) -> int:
    """Fix all key fields in a section. Returns count of changes."""
    sec_start, sec_end = _section_range(lines, section)
    if sec_start < 0:
        return 0

    raw = "".join(lines)
    data = yaml.safe_load(raw) or {}
    entries = data.get(section, []) or []

    total = 0
    for entry in entries:
        eid = entry.get(id_field, "")
        if not eid:
            continue
        expected = f"{key_prefix}_{to_ss(eid)}{suffix}"
        actual = entry.get(key_field, "")
        if actual == expected:
            continue

        id_line = _find_entry_id_line(lines, sec_start, sec_end, id_field, eid)
        if id_line < 0:
            continue
        key_line = _find_key_line(lines, id_line, key_field)
        if key_line < 0:
            continue

        ws = lines[key_line][: len(lines[key_line]) - len(lines[key_line].lstrip())]
        lines[key_line] = f"{ws}{key_field}: {expected}\n"
        total += 1

    return total


def fix_file(path: Path) -> int:
    """Fix all key naming violations in a file. Returns count of fixes."""
    fname = path.name
    rules = RULES_BY_FILE.get(fname)
    if not rules:
        return 0

    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return 0

    lines = text.splitlines(keepends=True)
    total = 0
    for rule in rules:
        total += _fix_section(lines, *rule)

    if total > 0:
        path.write_text("".join(lines), encoding="utf-8")

    return total


# ── CLI entry point ───────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Check/fix localization key naming conventions in gameplay YAML files. "
            "Without --fix, only reports violations (exit 1). "
            "With --fix, auto-corrects in place."
        )
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Auto-fix violations in place",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Specific YAML files to check (default: all known files under data/yaml/)",
    )
    args = parser.parse_args()

    if args.files:
        targets = [Path(f) for f in args.files if Path(f).is_file()]
    else:
        yaml_dir = PROJECT_ROOT / YAML_DIR
        if not yaml_dir.is_dir():
            sys.exit(f"YAML directory not found: {yaml_dir}")
        files = list(RULES_BY_FILE.keys())
        targets = [yaml_dir / f for f in files if (yaml_dir / f).is_file()]

    if not targets:
        sys.exit("No YAML files found to check.")

    if args.fix:
        fixed_total = 0
        for f in sorted(set(targets)):
            n = fix_file(f)
            if n > 0:
                rel = _rel(f)
                print(f"  {rel}: {n} field(s) fixed")
                fixed_total += n
        if fixed_total > 0:
            print(f"\n{fixed_total} field(s) fixed across {len(targets)} file(s).")
        else:
            print("No fixes needed.")
        return

    all_violations: list[Violation] = []
    for f in sorted(set(targets)):
        all_violations.extend(lint_file(f))

    if all_violations:
        print(f"yaml-keys: {len(all_violations)} violation(s)\n")
        for v in all_violations:
            print(v.format())
        sys.exit(1)

    print("yaml-keys: OK")


if __name__ == "__main__":
    main()
