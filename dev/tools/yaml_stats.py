"""
yaml_stats.py
Print per-super-category statistics for design balancing from the merged YAML
data set (item count, rarity distribution, anchor value aggregates, surface
clue counts, and hidden clue distributions).

When data/yaml/reference_tables.yaml exists, also compares per-category actual
value statistics against the authored reference bands and emits out-of-band
warnings for any category whose distribution falls outside its target range.

This script is read-only — it never writes or modifies YAML or TRES files.

Usage:
    python yaml_stats.py --godot-root /path/to/godot/project
    python yaml_stats.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import math
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
        "anchors": [],
        "clues": [],
    }

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    return merged


def _load_reference_tables(yaml_dir: Path) -> dict[str, dict]:
    """Load per-category reference bands from reference_tables.yaml.

    Returns a dict keyed by category_id:
      {
        "median": {"min": ..., "max": ...},
        "mean":   {"min": ..., "max": ...},
        "stddev": {"min": ..., "max": ...},
        "min":    {"min": ..., "max": ...},
        "max":    {"min": ..., "max": ...},
      }
    Missing file returns an empty dict (no reference checking).
    """
    ref_path = yaml_dir / "reference_tables.yaml"
    if not ref_path.exists():
        return {}
    data = yaml.safe_load(ref_path.read_text(encoding="utf-8"))
    if not data or "reference_tables" not in data:
        return {}
    result: dict[str, dict] = {}
    for entry in data["reference_tables"]:
        cat_id = entry.get("category_id")
        if cat_id:
            result[cat_id] = entry
    return result


# ── Stats helpers ─────────────────────────────────────────────────────────────


def _format_int(value: float) -> str:
    return f"{int(round(value)):,}"


def _extract_anchor_value(item: dict, anchors_by_id: dict[str, dict]) -> float | None:
    """Extract the anchor base_value from the anchors table."""
    anchor_id = item.get("anchor_id", "")
    anchor = anchors_by_id.get(anchor_id)
    if anchor:
        try:
            return float(anchor["base_value"])
        except (KeyError, ValueError, TypeError):
            return None
    return None


def _full_true_value(
    item: dict,
    anchors_by_id: dict[str, dict],
    clues_by_id: dict[str, dict],
) -> float | None:
    """Compute the item's full true value (all clues applied, ignoring reveal state).

    Formula mirrors ItemEntry.full_true_value():
      (effective_base + Σ_all_add) × Π_all_mul
    where effective_base = the first revealed hidden override amount,
    otherwise anchor.base_value. 'override' replaces the base; no longer 'flat'.
    """
    anchor_id = item.get("anchor_id", "")
    anchor = anchors_by_id.get(anchor_id)
    if not anchor:
        return None
    try:
        base = float(anchor["base_value"])
    except (KeyError, ValueError, TypeError):
        return None

    surface_ids = item.get("surface_ids", []) or []
    hidden_ids = item.get("hidden_ids", []) or []

    s_add = 0.0
    s_mul = 1.0
    h_add = 0.0
    h_mul = 1.0
    override: float | None = None

    for cid in surface_ids:
        clue = clues_by_id.get(cid)
        if not clue:
            continue
        op = clue.get("effect_op", "")
        try:
            amount = float(clue.get("effect_amount", 0))
        except (ValueError, TypeError):
            continue
        if op == "add":
            s_add += amount
        elif op == "mul":
            s_mul *= amount

    for cid in hidden_ids:
        clue = clues_by_id.get(cid)
        if not clue:
            continue
        op = clue.get("effect_op", "")
        try:
            amount = float(clue.get("effect_amount", 0))
        except (ValueError, TypeError):
            continue
        if op == "override" and override is None:
            override = amount
        elif op == "add":
            h_add += amount
        elif op == "mul":
            h_mul *= amount

    effective_base = override if override is not None else base
    return (effective_base + s_add + h_add) * s_mul * h_mul


def _count_surface_clues(item: dict) -> int:
    clues = item.get("clues", []) or []
    return sum(1 for c in clues if c.get("type") == "surface")


def _count_hidden_clues(item: dict) -> int:
    clues = item.get("clues", []) or []
    return sum(1 for c in clues if c.get("type") == "hidden")


def _value_stats(values: list[float]) -> dict:
    """Compute mean, median, stddev, min, max for a list of floats."""
    if not values:
        return {}
    n = len(values)
    mean = sum(values) / n
    sorted_v = sorted(values)
    mid = n // 2
    median = sorted_v[mid] if n % 2 else (sorted_v[mid - 1] + sorted_v[mid]) / 2.0
    variance = sum((v - mean) ** 2 for v in values) / n
    stddev = math.sqrt(variance)
    return {
        "mean": mean,
        "median": median,
        "stddev": stddev,
        "min": sorted_v[0],
        "max": sorted_v[-1],
        "count": n,
    }


def _check_reference_band(
    stat_name: str,
    actual: float,
    band: dict,
    cat_id: str,
    warnings: list[str],
) -> None:
    low = band.get("min")
    high = band.get("max")
    if low is not None and actual < low:
        warnings.append(
            f"  [WARN] {cat_id}: {stat_name} {actual:.1f} is below reference min {low}"
        )
    if high is not None and actual > high:
        warnings.append(
            f"  [WARN] {cat_id}: {stat_name} {actual:.1f} is above reference max {high}"
        )


def _print_rarity_table(
    items: list[dict],
    anchors_by_id: dict[str, dict],
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
        val = _extract_anchor_value(item, anchors_by_id)
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
    ref_tables = _load_reference_tables(yaml_dir)

    if ref_tables:
        print(f"Reference tables loaded for {len(ref_tables)} categories.")
    else:
        print("No reference_tables.yaml found — skipping reference band checks.")

    # Build lookup tables for the post-cleanup three-way schema.
    anchors_by_id: dict[str, dict] = {
        a["anchor_id"]: a for a in merged.get("anchors", [])
    }
    clues_by_id: dict[str, dict] = {
        c["clue_id"]: c for c in merged.get("clues", [])
    }

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
    all_ref_warnings: list[str] = []

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
        super_anchors = _print_rarity_table(items, anchors_by_id, indent="  ")
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
            _print_rarity_table(cat_items, anchors_by_id, indent="      ")

            # ── Reference table comparison ────────────────────────────────
            if cat_id in ref_tables:
                ref = ref_tables[cat_id]
                true_values = [
                    v for it in cat_items
                    if (v := _full_true_value(it, anchors_by_id, clues_by_id)) is not None
                ]
                stats = _value_stats(true_values)
                if stats:
                    ref_warnings: list[str] = []
                    for stat_name in ("mean", "median", "stddev", "min", "max"):
                        band = ref.get(stat_name)
                        if isinstance(band, dict) and stat_name in stats:
                            _check_reference_band(
                                stat_name,
                                stats[stat_name],
                                band,
                                cat_id,
                                ref_warnings,
                            )
                    if ref_warnings:
                        for w in ref_warnings:
                            print(w)
                        all_ref_warnings.extend(ref_warnings)

        print()

    # Grand total
    print(separator)
    print(
        f"Total: {total_items} items across {len(items_by_super_cat)} super-categories"
    )

    if all_ref_warnings:
        print(f"\n{len(all_ref_warnings)} reference band warning(s) — see above for details.")
    elif ref_tables:
        print("\nAll categories within reference band targets.")


if __name__ == "__main__":
    main()
