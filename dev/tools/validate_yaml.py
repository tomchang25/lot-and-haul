"""
validate_yaml.py
Validate merged YAML data for the lot-and-haul data pipeline.

Can be used standalone (for CI, pre-commit hooks, or authoring-time checks)
or imported by yaml_to_tres.py as part of the full TRES generation pipeline.

Usage:
    python validate_yaml.py --yaml-dir path/to/data/yaml

Where cross-entity checks live
------------------------------
There are two homes for validation that spans more than one entity. Pick by
*who owns the invariant*, not by convenience:

  * Referential ("I reference X — does X exist?") — asymmetric, owned by the
    entity that holds the dangling reference. Put it in that entity's
    ``spec.validate(entries, all_data)`` (it already receives ``all_data``).
    Examples: lot -> category, affix -> clue, category -> super_category.

  * Aggregate / coverage ("every X must be covered by some Y", or any invariant
    over whole collections with no single owning entity) — symmetric, owned by
    neither side. Put it in ``CROSS_ENTITY_VALIDATORS`` below.

When unsure, ask: "could this be expressed as one record validating itself
against the rest of the data?" Yes -> spec. No (it's about the set as a whole)
-> CROSS_ENTITY_VALIDATORS.
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from tres_lib.registry import REGISTRY


# ── Cross-entity validators ──────────────────────────────────────────────────
#
# Each validator takes the merged ``data`` dict and returns a list of error
# strings (empty = OK). Register new aggregate/coverage checks by adding the
# function to CROSS_ENTITY_VALIDATORS at the bottom of this section — see the
# module docstring for the reference-vs-coverage boundary rule.


def _check_category_affix_coverage(data: dict) -> list[str]:
    """Every category must have at least one affix in its category_scope."""
    errors: list[str] = []
    categories: list[dict] = data.get("categories", [])
    affixes: list[dict] = data.get("affixes", [])

    if not categories:
        return errors

    covered: set[str] = set()
    for affix in affixes:
        scope = affix.get("category_scope", [])
        if not scope:
            continue
        for cat_id in scope:
            covered.add(cat_id)

    for cat in categories:
        cat_id = cat.get("category_id", "")
        if not cat_id:
            continue
        if cat_id.startswith("test_"):
            continue
        if cat_id not in covered:
            errors.append(
                f"category '{cat_id}' has no affixes — add affix entries "
                f"in data/yaml/affixes.yaml"
            )

    return errors


# Aggregate/coverage invariants with no single owning entity. Add new ones here;
# each must be a ``Callable[[dict], list[str]]``. Referential checks belong in
# the owning entity's spec.validate instead (see module docstring).
CROSS_ENTITY_VALIDATORS = [
    _check_category_affix_coverage,
]


# ── Public API ───────────────────────────────────────────────────────────────


def validate(data: dict) -> list[str]:
    """Validate merged YAML data, including embedded resource fields and
    cross-entity integrity checks.

    Returns list of error strings.
    Empty list means OK."""
    errors: list[str] = []
    for spec in REGISTRY:
        errors.extend(spec.validate(data.get(spec.yaml_key, []), data))
    for check in CROSS_ENTITY_VALIDATORS:
        errors.extend(check(data))
    return errors


# ── CLI entry point ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate YAML data files for the lot-and-haul data pipeline."
    )
    parser.add_argument(
        "--yaml-dir",
        required=True,
        help="Directory containing YAML files to validate",
    )
    args = parser.parse_args()

    yaml_dir = Path(args.yaml_dir)
    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    yaml_files = sorted(yaml_dir.glob("**/*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {spec.yaml_key: [] for spec in REGISTRY}

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in list(merged.keys()):
            merged[key].extend(data.get(key, []) or [])

    print("Validating...")
    errors = validate(merged)
    if errors:
        print(f"  {len(errors)} error(s) found:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")


if __name__ == "__main__":
    main()
