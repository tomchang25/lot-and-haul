"""
yaml_stats.py
Print per-super-category statistics for design balancing from the merged YAML
data set (item count, rarity distribution, final-layer base_value aggregates
including median, and average layer depth).

This script is read-only — it never writes or modifies YAML or TRES files.

Usage:
    python yaml_stats.py --godot-root /path/to/godot/project
    python yaml_stats.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import statistics
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
    """Glob and merge every ``*.yaml`` file in ``yaml_dir``.

    Mirrors the merge pattern used by ``yaml_to_tres.py`` so both tools see
    the exact same dataset.
    """
    yaml_files = sorted(yaml_dir.glob("**/*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {
        "skills": [],
        "super_categories": [],
        "categories": [],
        "identity_layers": [],
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


def _safe_stdev(values: list[float]) -> float:
    """Population stdev that tolerates single-sample inputs (returns 0.0)."""
    if len(values) < 2:
        return 0.0
    return statistics.pstdev(values)


def _safe_median(values: list[float]) -> float:
    """Median that tolerates empty inputs (returns 0.0)."""
    if not values:
        return 0.0
    return statistics.median(values)


def _final_value(item: dict, layers_by_id: dict[str, dict]) -> float | None:
    """Extract the base_value of the item's final identity layer, or None."""
    layer_ids = item.get("layer_ids", []) or []
    if not layer_ids:
        return None
    final_layer = layers_by_id.get(layer_ids[-1])
    if final_layer is None:
        return None
    bv = final_layer.get("base_value")
    return float(bv) if bv is not None else None


def _print_rarity_value_table(
    items: list[dict],
    layers_by_id: dict[str, dict],
    indent: str = "  ",
) -> list[float]:
    """Print per-rarity value stats and return all final values collected.

    Each rarity tier gets one line with count, avg, med, min, max.
    """
    # bucket values by rarity
    by_rarity: dict[int, list[float]] = {}
    rarity_counts: dict[int, int] = {}
    all_values: list[float] = []

    for item in items:
        r = int(item.get("rarity", 0))
        rarity_counts[r] = rarity_counts.get(r, 0) + 1
        val = _final_value(item, layers_by_id)
        if val is not None:
            by_rarity.setdefault(r, []).append(val)
            all_values.append(val)

    # determine column width for rarity name alignment
    max_name_len = max(
        (len(RARITY_NAMES.get(r, f"RARITY_{r}")) for r in rarity_counts),
        default=6,
    )

    for r in sorted(rarity_counts):
        name = RARITY_NAMES.get(r, f"RARITY_{r}")
        count = rarity_counts[r]
        vals = by_rarity.get(r, [])
        if vals:
            line = (
                f"{indent}{name:<{max_name_len}} ({count:>3})"
                f" — avg: {_format_int(statistics.mean(vals)):>7}"
                f"  med: {_format_int(_safe_median(vals)):>7}"
                f"  min: {_format_int(min(vals)):>7}"
                f"  max: {_format_int(max(vals)):>7}"
            )
        else:
            line = f"{indent}{name:<{max_name_len}} ({count:>3}) — (no value data)"
        print(line)

    return all_values


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

    layers_by_id: dict[str, dict] = {
        l["layer_id"]: l for l in merged.get("identity_layers", [])
    }

    # ── Build category → super_category lookup ───────────────────────────────
    cat_to_super: dict[str, str] = {}
    for cat in merged.get("categories", []):
        cat_to_super[cat["category_id"]] = cat.get("super_category", "unknown")

    # ── Build super_category display name lookup ─────────────────────────────
    super_display: dict[str, str] = {}
    for sc in merged.get("super_categories", []):
        super_display[sc["super_category_id"]] = sc.get(
            "display_name", sc["super_category_id"]
        )

    # ── Group items by super_category, then by category ─────────────────────
    # Nested: super_id -> cat_id -> [items]
    items_by_super_cat: dict[str, dict[str, list[dict]]] = {}
    for item in merged.get("items", []):
        cat_id = item.get("category_id", "?")
        super_id = cat_to_super.get(cat_id, "unknown")
        items_by_super_cat.setdefault(super_id, {}).setdefault(cat_id, []).append(item)

    if not items_by_super_cat:
        print("\nNo items found.")
        return

    separator = "═" * 60

    all_final_values: list[float] = []
    total_items = 0
    first = True

    for super_id in sorted(items_by_super_cat):
        cats_dict = items_by_super_cat[super_id]
        # Flatten for super-category-level aggregates
        items = [it for cat_items in cats_dict.values() for it in cat_items]
        total_items += len(items)

        depths = [len(item.get("layer_ids", []) or []) for item in items]
        avg_depth = statistics.mean(depths) if depths else 0.0

        # ── Super-category header ────────────────────────────────────────
        if not first:
            print(separator)
        first = False

        display = super_display.get(super_id, super_id)
        print(
            f"\nSuper-category: {display} [{super_id}]"
            f" ({len(items)} items, {len(cats_dict)} categories,"
            f" avg depth: {avg_depth:.1f})"
        )
        super_values = _print_rarity_value_table(items, layers_by_id, indent="  ")
        all_final_values.extend(super_values)

        # ── Per-category breakdown ───────────────────────────────────────
        for cat_id in sorted(cats_dict):
            cat_items = cats_dict[cat_id]
            cat_depths = [len(it.get("layer_ids", []) or []) for it in cat_items]
            cat_avg_depth = statistics.mean(cat_depths) if cat_depths else 0.0
            print(
                f"    {cat_id} ({len(cat_items)} items,"
                f" avg depth: {cat_avg_depth:.1f})"
            )
            _print_rarity_value_table(cat_items, layers_by_id, indent="      ")

        print()

    # ── Grand total ──────────────────────────────────────────────────────────
    print(separator)
    print(
        f"Total: {total_items} items across {len(items_by_super_cat)} super-categories"
    )
    if all_final_values:
        print(
            f"  Final value — avg: {_format_int(statistics.mean(all_final_values))}"
            f"  med: {_format_int(_safe_median(all_final_values))}"
            f"  std: {_format_int(_safe_stdev(all_final_values))}"
        )


if __name__ == "__main__":
    main()
