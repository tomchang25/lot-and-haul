"""
yaml_stats.py
Print per-super-category statistics for design balancing from the merged YAML
data set (item count, rarity distribution, anchor value aggregates, surface
clue counts, and hidden clue distributions).

This script is read-only — it never writes or modifies YAML or TRES files.

Usage:
    python yaml_stats.py --godot-root /path/to/godot/project
    python yaml_stats.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── Rarity labels ─────────────────────────────────────────────────────────────

RARITY_NAMES = {
    0: "COMMON",
    1: "UNCOMMON",
    2: "RARE",
    3: "EPIC",
    4: "LEGENDARY",
}


# ── Loading ───────────────────────────────────────────────────────────────────


def _load_merged(yaml_dir: Path) -> dict[str, list]:
    """Glob and merge every ``*.yaml`` file in ``yaml_dir``."""
    yaml_files = sorted(yaml_dir.glob("**/*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {
        "super_categories": [],
        "categories": [],
        "items": [],
    }

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    return merged


# ── Stats helpers ─────────────────────────────────────────────────────────────


def _format_int(value: float) -> str:
    return f"{int(round(value)):,}"


def _extract_anchor_value(item: dict) -> float | None:
    """Extract the anchor clue's price effect as a numeric value."""
    clues = item.get("clues", []) or []
    for clue in clues:
        if clue.get("type") == "anchor":
            try:
                return float(clue["effect_amount"])
            except (KeyError, ValueError, TypeError):
                return None
    return None


def _count_surface_clues(item: dict) -> int:
    clues = item.get("clues", []) or []
    return sum(1 for c in clues if c.get("type") == "surface")


def _count_hidden_clues(item: dict) -> int:
    clues = item.get("clues", []) or []
    return sum(1 for c in clues if c.get("type") == "hidden")


def _print_rarity_table(
    items: list[dict],
    indent: str = "  ",
) -> list[float]:
    """Print per-rarity stats and return all anchor values collected."""
    by_rarity: dict[int, list[dict]] = {}
    rarity_counts: dict[int, int] = {}
    all_anchors: list[float] = []

    for item in items:
        r = int(item.get("rarity", 0))
        rarity_counts[r] = rarity_counts.get(r, 0) + 1
        by_rarity.setdefault(r, []).append(item)
        val = _extract_anchor_value(item)
        if val is not None:
            all_anchors.append(val)

    max_name_len = max(
        (len(RARITY_NAMES.get(r, f"RARITY_{r}")) for r in rarity_counts),
        default=6,
    )

    for r in sorted(rarity_counts):
        name = RARITY_NAMES.get(r, f"RARITY_{r}")
        count = rarity_counts[r]
        items_in_rarity = by_rarity.get(r, [])
        surface_counts = [_count_surface_clues(it) for it in items_in_rarity]
        hidden_counts = [_count_hidden_clues(it) for it in items_in_rarity]
        avg_surface = sum(surface_counts) / len(surface_counts) if surface_counts else 0
        avg_hidden = sum(hidden_counts) / len(hidden_counts) if hidden_counts else 0

        line = (
            f"{indent}{name:<{max_name_len}} ({count:>3})"
            f" — avg surface: {avg_surface:.1f}"
            f"  avg hidden: {avg_hidden:.1f}"
        )
        print(line)

    return all_anchors


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print per-super-category YAML statistics for design balancing."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--yaml-dir",
        default=None,
        help="Directory containing YAML files (default: <godot-root>/data/yaml)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    yaml_dir = Path(args.yaml_dir) if args.yaml_dir else root / "data" / "yaml"

    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    merged = _load_merged(yaml_dir)

    # Build category -> super_category lookup
    cat_to_super: dict[str, str] = {}
    for cat in merged.get("categories", []):
        cat_to_super[cat["category_id"]] = cat.get("super_category", "unknown")

    # Build super_category display name lookup
    super_display: dict[str, str] = {}
    for sc in merged.get("super_categories", []):
        super_display[sc["super_category_id"]] = sc.get(
            "display_name", sc["super_category_id"]
        )

    # Group items by super_category, then by category
    items_by_super_cat: dict[str, dict[str, list[dict]]] = {}
    for item in merged.get("items", []):
        cat_id = item.get("category_id", "?")
        super_id = cat_to_super.get(cat_id, "unknown")
        items_by_super_cat.setdefault(super_id, {}).setdefault(cat_id, []).append(item)

    if not items_by_super_cat:
        print("\nNo items found.")
        return

    separator = "=" * 60

    all_anchor_values: list[float] = []
    total_items = 0
    first = True

    for super_id in sorted(items_by_super_cat):
        cats_dict = items_by_super_cat[super_id]
        items = [it for cat_items in cats_dict.values() for it in cat_items]
        total_items += len(items)

        surface_counts = [_count_surface_clues(it) for it in items]
        hidden_counts = [_count_hidden_clues(it) for it in items]
        avg_surface = sum(surface_counts) / len(surface_counts) if surface_counts else 0
        avg_hidden = sum(hidden_counts) / len(hidden_counts) if hidden_counts else 0

        if not first:
            print(separator)
        first = False

        display = super_display.get(super_id, super_id)
        print(
            f"\nSuper-category: {display} [{super_id}]"
            f" ({len(items)} items, {len(cats_dict)} categories,"
            f" avg surface clues: {avg_surface:.1f},"
            f" avg hidden clues: {avg_hidden:.1f})"
        )
        super_anchors = _print_rarity_table(items, indent="  ")
        all_anchor_values.extend(super_anchors)

        for cat_id in sorted(cats_dict):
            cat_items = cats_dict[cat_id]
            cat_surface = [_count_surface_clues(it) for it in cat_items]
            cat_hidden = [_count_hidden_clues(it) for it in cat_items]
            avg_cat_surface = sum(cat_surface) / len(cat_surface) if cat_surface else 0
            avg_cat_hidden = sum(cat_hidden) / len(cat_hidden) if cat_hidden else 0
            print(
                f"    {cat_id} ({len(cat_items)} items,"
                f" avg surface: {avg_cat_surface:.1f},"
                f" avg hidden: {avg_cat_hidden:.1f})"
            )
            _print_rarity_table(cat_items, indent="      ")

        print()

    # Grand total
    print(separator)
    print(
        f"Total: {total_items} items across {len(items_by_super_cat)} super-categories"
    )
