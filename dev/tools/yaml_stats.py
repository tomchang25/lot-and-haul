"""
yaml_stats.py
Print per-category statistics for design balancing from the merged YAML data
set (item count, rarity distribution, final-layer base_value aggregates, and
average layer depth).

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
    yaml_files = sorted(yaml_dir.glob("*.yaml"))
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


def _rarity_summary(rarity_counts: dict[int, int]) -> str:
    parts: list[str] = []
    for rarity in sorted(rarity_counts):
        name = RARITY_NAMES.get(rarity, f"RARITY_{rarity}")
        parts.append(f"{rarity_counts[rarity]} {name}")
    return ", ".join(parts) if parts else "(none)"


def _safe_stdev(values: list[float]) -> float:
    """Population stdev that tolerates single-sample inputs (returns 0.0)."""
    if len(values) < 2:
        return 0.0
    return statistics.pstdev(values)


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print per-category YAML statistics for design balancing."
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

    # ── Group items by category ──────────────────────────────────────────────
    items_by_category: dict[str, list[dict]] = {}
    for item in merged.get("items", []):
        cat_id = item.get("category_id", "?")
        items_by_category.setdefault(cat_id, []).append(item)

    if not items_by_category:
        print("\nNo items found.")
        return

    print()

    all_final_values: list[float] = []
    total_items = 0

    for cat_id in sorted(items_by_category):
        items = items_by_category[cat_id]
        total_items += len(items)

        depths: list[int] = []
        final_values: list[float] = []
        rarity_counts: dict[int, int] = {}

        for item in items:
            layer_ids = item.get("layer_ids", []) or []
            depths.append(len(layer_ids))

            rarity = int(item.get("rarity", 0))
            rarity_counts[rarity] = rarity_counts.get(rarity, 0) + 1

            if layer_ids:
                final_layer = layers_by_id.get(layer_ids[-1])
                if final_layer is not None:
                    base_value = final_layer.get("base_value")
                    if base_value is not None:
                        final_values.append(float(base_value))

        avg_depth = statistics.mean(depths) if depths else 0.0
        all_final_values.extend(final_values)

        print(f"Category: {cat_id} ({len(items)} items, avg depth: {avg_depth:.1f})")
        print(f"  Rarity: {_rarity_summary(rarity_counts)}")

        if final_values:
            avg_value = statistics.mean(final_values)
            std_value = _safe_stdev(final_values)
            min_value = min(final_values)
            max_value = max(final_values)
            print(
                f"  Final value — avg: {_format_int(avg_value)}"
                f"  std: {_format_int(std_value)}"
                f"  min: {_format_int(min_value)}"
                f"  max: {_format_int(max_value)}"
            )
        else:
            print("  Final value — (no data)")

        print()

    # ── Grand total ──────────────────────────────────────────────────────────
    print("──────────────────────────────────")
    print(f"Total: {total_items} items across {len(items_by_category)} categories")
    if all_final_values:
        grand_avg = statistics.mean(all_final_values)
        grand_std = _safe_stdev(all_final_values)
        print(
            f"  Final value — avg: {_format_int(grand_avg)}"
            f"  std: {_format_int(grand_std)}"
        )


if __name__ == "__main__":
    main()
