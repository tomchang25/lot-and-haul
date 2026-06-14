"""
balance_preview.py — Offline pool-generation balance preview tool.

Simulates N draws per lot configuration from YAML sources and reports value
distributions plus content-health flags. Mirrors the draw logic of
ItemGenerator.gd and the price pipeline of ItemEntry.gd.

Usage:
    python balance_preview.py --yaml-dir /path/to/data/yaml [--samples 10000]
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── Constants ─────────────────────────────────────────────────────────────────

SURFACE_CLUE_MIN = 2
SURFACE_CLUE_MAX = 4
HARD_SURFACE_MIN = 1
HARD_SURFACE_MAX = 8
TIER_KEYS = [1, 2, 3, 4, 5]

# Soft thresholds for low-information clue detection.
# A clue is flagged as low-info when both spread shrinkage and mean shift
# fall below these thresholds.
LOW_INFO_SHRINK_THRESHOLD = 0.05
LOW_INFO_SHIFT_THRESHOLD = 0.05

# ANSI color codes for terminal output.
YELLOW = "\033[33m"
RESET = "\033[0m"


# ── Data classes (mirroring Godot resources) ──────────────────────────────────


@dataclass
class CategoryData:
    category_id: str
    super_category: str = ""
    display_name: str = ""


@dataclass
class AnchorData:
    anchor_id: str
    known_text: str = ""
    naming_priority: int = 1
    category_scope: str = ""
    base_value: float = 0.0
    tier: int = 1


@dataclass
class ClueData:
    clue_id: str
    known_text: str = ""
    type: str = "surface"  # "surface" or "hidden"
    domain: str = "generic"
    attribute: str = ""
    dc: int = 10
    effect_op: str = "add"
    effect_amount: float = 0.0
    exclusive_group: str = ""
    naming_slot: str = ""
    naming_priority: int = 0


# ── YAML loading ──────────────────────────────────────────────────────────────


def _load_yaml(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_categories(yaml_dir: Path) -> dict[str, CategoryData]:
    """Load categories from category_data.yaml. Returns dict keyed by category_id."""
    data = _load_yaml(yaml_dir / "category_data.yaml")
    result: dict[str, CategoryData] = {}
    for entry in data.get("categories", []):
        c = CategoryData(
            category_id=entry["category_id"],
            super_category=entry.get("super_category", ""),
            display_name=entry.get("display_name", entry["category_id"]),
        )
        result[c.category_id] = c
    return result


def load_anchors_and_clues(
    yaml_dir: Path,
) -> tuple[list[AnchorData], list[ClueData]]:
    """Load anchors and clues from clues.yaml."""
    data = _load_yaml(yaml_dir / "clues.yaml")
    anchors: list[AnchorData] = []
    for entry in data.get("anchors", []):
        a = AnchorData(
            anchor_id=entry["anchor_id"],
            known_text=entry.get("known_text", ""),
            naming_priority=entry.get("naming_priority", 1),
            category_scope=entry.get("category_scope", ""),
            base_value=float(entry.get("base_value", 0)),
            tier=int(entry.get("tier", 1)),
        )
        anchors.append(a)

    clues: list[ClueData] = []
    for entry in data.get("clues", []):
        naming = entry.get("naming", {}) or {}
        c = ClueData(
            clue_id=entry["clue_id"],
            known_text=entry.get("known_text", ""),
            type=entry.get("type", "surface"),
            domain=entry.get("domain", "generic"),
            attribute=entry.get("attribute", ""),
            dc=int(entry.get("dc", 10)),
            effect_op=entry.get("effect_op", "add"),
            effect_amount=float(entry.get("effect_amount", 0)),
            exclusive_group=entry.get("exclusive_group", ""),
            naming_slot=naming.get("slot", ""),
            naming_priority=naming.get("priority", 0),
        )
        clues.append(c)

    return anchors, clues


def load_lots(yaml_dir: Path) -> list[dict]:
    """Load lot definitions from location_data.yaml."""
    data = _load_yaml(yaml_dir / "location_data.yaml")
    return data.get("lots", [])


def load_affixes(yaml_dir: Path) -> tuple[list[dict], dict[str, dict]]:
    """Load affixes and combinations from affixes.yaml.

    Returns (affixes, combinations_by_id).
    """
    data = (
        _load_yaml(yaml_dir / "affixes.yaml")
        if (yaml_dir / "affixes.yaml").exists()
        else {}
    )
    affixes: list[dict] = data.get("affixes", [])
    combos: list[dict] = data.get("affix_combinations", [])
    combos_by_id: dict[str, dict] = {c["combination_id"]: c for c in combos}
    return affixes, combos_by_id


# ── Draw helpers ──────────────────────────────────────────────────────────────


def pick_weighted_index(weights: list[int], rng: random.Random) -> int:
    if not weights:
        return -1
    total = sum(max(w, 0) for w in weights)
    if total <= 0:
        return -1
    roll = rng.randint(1, total)
    cumulative = 0
    for i, w in enumerate(weights):
        cumulative += max(w, 0)
        if roll <= cumulative:
            return i
    return -1


def draw_anchor(
    category_scope: str,
    tier_weights: dict[int, int],
    anchors: list[AnchorData],
    rng: random.Random,
) -> AnchorData | None:
    """Draw an anchor matching category_scope. See ItemGenerator._draw_anchor."""
    cat_anchors = [a for a in anchors if a.category_scope == category_scope]
    if not cat_anchors:
        return None

    has_weight = any(v > 0 for v in tier_weights.values())
    if not has_weight:
        return rng.choice(cat_anchors)

    tier_keys = list(tier_weights.keys())
    tier_vals = [tier_weights[k] for k in tier_keys]
    idx = pick_weighted_index(tier_vals, rng)
    if idx < 0:
        return rng.choice(cat_anchors)

    picked_tier = tier_keys[idx]
    tier_anchors = [a for a in cat_anchors if a.tier == picked_tier]

    if tier_anchors:
        return rng.choice(tier_anchors)

    best_tier = -1
    best_dist = 999
    for t in TIER_KEYS:
        dist = abs(t - picked_tier)
        if any(a.tier == t for a in cat_anchors):
            if dist < best_dist or (dist == best_dist and t < best_tier):
                best_dist = dist
                best_tier = t

    if best_tier < 0:
        return rng.choice(cat_anchors)

    fallback = [a for a in cat_anchors if a.tier == best_tier]
    return rng.choice(fallback)


def _affix_matches_category(affix: dict, category_id: str) -> bool:
    """Check if affix is eligible for the given category.

    Mirrors ItemGenerator._affix_matches_category.
    """
    scope_mode = affix.get("scope_mode", "categories")
    if scope_mode == "all":
        return True
    category_scope = affix.get("category_scope", []) or []
    return category_id in category_scope


def _draw_affixes(
    category_id: str,
    affixes: list[dict],
    rng: random.Random,
) -> list[dict]:
    """Draw 0-1 prefix + 0-1 suffix affixes for category.

    Mirrors ItemGenerator._draw_affixes.
    """
    candidates = [a for a in affixes if _affix_matches_category(a, category_id)]
    if not candidates:
        return []

    total_weight = sum(max(a.get("weight", 0), 0) for a in candidates)
    if total_weight <= 0:
        return []

    chosen: list[dict] = []

    # Prefix pool (up to 1)
    prefix_pool = [a for a in candidates if a.get("naming_slot") == "prefix"]
    if prefix_pool:
        roll = rng.randint(1, total_weight)
        cumulative = 0
        for a in prefix_pool:
            cumulative += max(a.get("weight", 0), 0)
            if roll <= cumulative:
                chosen.append(a)
                break

    # Suffix pool (up to 1)
    suffix_pool = [a for a in candidates if a.get("naming_slot") == "suffix"]
    if suffix_pool:
        roll = rng.randint(1, total_weight)
        cumulative = 0
        for a in suffix_pool:
            cumulative += max(a.get("weight", 0), 0)
            if roll <= cumulative:
                if a not in chosen:
                    chosen.append(a)
                break

    return chosen


def _pick_combination(
    affix: dict,
    combinations: dict[str, dict],
    rng: random.Random,
) -> dict | None:
    """Weight-pick one combination from the affix's combination list.

    Mirrors ItemGenerator._pick_combination.
    """
    comb_ids = affix.get("combination_ids", []) or []
    if not comb_ids:
        return None

    weights: list[int] = []
    available: list[dict] = []
    for cid in comb_ids:
        comb = combinations.get(cid)
        if comb is not None:
            weights.append(max(comb.get("weight", 0), 0))
            available.append(comb)

    if not available:
        return None

    idx = pick_weighted_index(weights, rng)
    if idx < 0 or idx >= len(available):
        return rng.choice(available) if available else None
    return available[idx]


def draw_surface_clues(
    category_id: str,
    count: int,
    clues: list[ClueData],
    rng: random.Random,
) -> list[ClueData]:
    """Draw surface clues (plain-item fallback). See ItemGenerator._draw_surface_clues."""
    pool = [
        c
        for c in clues
        if c.type == "surface" and (c.domain == "generic" or c.domain == category_id)
    ]
    actual = min(count, len(pool))
    if actual == 0:
        return []
    return rng.sample(pool, actual)


# ── Price pipeline (mirroring ItemEntry) ──────────────────────────────────────


def _full_true_value(
    anchor: AnchorData,
    surface_ids: list[str],
    hidden_ids: list[str],
    clues_by_id: dict[str, ClueData],
) -> float:
    """Full potential value with ALL clues applied.

    Mirrors ItemEntry.full_true_value(). Override replaces base; add/mul apply
    to all clues regardless of type.
    """
    base = anchor.base_value
    for cid in hidden_ids:
        clue = clues_by_id[cid]
        if clue.effect_op == "override":
            base = clue.effect_amount
            break

    add_sum = 0.0
    mul_prod = 1.0
    for cid in surface_ids + hidden_ids:
        clue = clues_by_id[cid]
        if clue.effect_op == "add":
            add_sum += clue.effect_amount
        elif clue.effect_op == "mul":
            mul_prod *= clue.effect_amount

    return (base + add_sum) * mul_prod


def _appraised_value(
    anchor: AnchorData,
    surface_ids: list[str],
    clues_by_id: dict[str, ClueData],
) -> float:
    """Appraised value from surface clues only. Mirrors ItemEntry._raw_appraised_value."""
    base = anchor.base_value
    add_sum = 0.0
    mul_prod = 1.0
    for cid in surface_ids:
        clue = clues_by_id[cid]
        if clue.effect_op == "add":
            add_sum += clue.effect_amount
        elif clue.effect_op == "mul":
            mul_prod *= clue.effect_amount
    return (base + add_sum) * mul_prod


# ── Simulation ────────────────────────────────────────────────────────────────


@dataclass
class DrawResult:
    anchor_id: str
    category_id: str
    tier: int
    affix_ids: list[str]
    combination_ids: list[str]
    surface_ids: list[str]
    hidden_ids: list[str]
    prior_value: float
    appraised_value: float
    full_true_value: float


def simulate_lot(
    lot: dict,
    categories: dict[str, CategoryData],
    anchors: list[AnchorData],
    clues: list[ClueData],
    affixes: list[dict],
    combinations: dict[str, dict],
    samples: int,
    rng: random.Random,
) -> list[DrawResult]:
    """Simulate N item draws for a given lot configuration.

    Mirrors ItemGenerator.draw(): category -> anchor -> affixes -> combinations -> clues.
    Falls back to plain-item baseline when no affix is drawn.
    """
    tier_weights = {int(k): int(v) for k, v in lot.get("tier_weights", {}).items()}
    cat_weights: dict[str, int] = lot.get("category_weights", {}) or {}
    sc_weights: dict[str, int] = lot.get("super_category_weights", {}) or {}
    surface_min = max(
        lot.get("surface_min", SURFACE_CLUE_MIN),
        HARD_SURFACE_MIN,
    )
    surface_max = min(
        lot.get("surface_max", SURFACE_CLUE_MAX),
        HARD_SURFACE_MAX,
    )

    clues_by_id: dict[str, ClueData] = {c.clue_id: c for c in clues}
    results: list[DrawResult] = []

    for _ in range(samples):
        # Draw category
        category_id = _draw_category(cat_weights, sc_weights, categories, rng)
        if category_id is None:
            continue

        cat = categories.get(category_id)
        if cat is None:
            continue

        # Draw anchor
        anchor = draw_anchor(category_id, tier_weights, anchors, rng)
        if anchor is None:
            continue

        prior_value = anchor.base_value

        # Draw affixes
        drawn_affixes = _draw_affixes(category_id, affixes, rng)

        surface_ids: list[str] = []
        hidden_ids: list[str] = []
        drawn_affix_ids: list[str] = []
        drawn_combination_ids: list[str] = []

        if drawn_affixes:
            for affix in drawn_affixes:
                comb = _pick_combination(affix, combinations, rng)
                if comb is None:
                    continue
                drawn_affix_ids.append(affix["affix_id"])
                drawn_combination_ids.append(comb["combination_id"])
                surface_ids.extend(comb.get("surface_clue_ids", []))
                hidden_ids.extend(comb.get("hidden_clue_ids", []))
        else:
            # Plain-item fallback: surface clues from generic pool, zero hidden
            surface_count = rng.randint(surface_min, surface_max)
            surface_clues = draw_surface_clues(category_id, surface_count, clues, rng)
            surface_ids = [c.clue_id for c in surface_clues]

        result = DrawResult(
            anchor_id=anchor.anchor_id,
            category_id=category_id,
            tier=anchor.tier,
            affix_ids=drawn_affix_ids,
            combination_ids=drawn_combination_ids,
            surface_ids=surface_ids,
            hidden_ids=hidden_ids,
            prior_value=prior_value,
            appraised_value=_appraised_value(anchor, surface_ids, clues_by_id),
            full_true_value=_full_true_value(
                anchor, surface_ids, hidden_ids, clues_by_id
            ),
        )
        results.append(result)

    return results


def _draw_category(
    cat_weights: dict[str, int],
    sc_weights: dict[str, int],
    categories: dict[str, CategoryData],
    rng: random.Random,
) -> str | None:
    """Draw a category_id from weighted tables."""
    if sc_weights:
        sc_keys = list(sc_weights.keys())
        sc_vals = [sc_weights[k] for k in sc_keys]
        idx = pick_weighted_index(sc_vals, rng)
        if idx < 0:
            return None
        sc_id = sc_keys[idx]
        members = [
            cid for cid, cat in categories.items() if cat.super_category == sc_id
        ]
        if not members:
            return None
        return rng.choice(members)

    if cat_weights:
        keys = list(cat_weights.keys())
        vals = [cat_weights[k] for k in keys]
        idx = pick_weighted_index(vals, rng)
        if idx < 0:
            return None
        return keys[idx]

    return None


# ── Reporting ─────────────────────────────────────────────────────────────────


def percentile(data: list[float], p: float) -> float:
    if not data:
        return 0.0
    data_sorted = sorted(data)
    k = (len(data_sorted) - 1) * p / 100.0
    f = int(k)
    c = f + 1 if f + 1 < len(data_sorted) else f
    if c == f:
        return data_sorted[f]
    return data_sorted[f] * (c - k) + data_sorted[c] * (k - f)


def _check_surface_pool(
    category_id: str,
    clues: list[ClueData],
) -> str | None:
    pool_size = sum(
        1
        for c in clues
        if c.type == "surface" and (c.domain == "generic" or c.domain == category_id)
    )
    if pool_size < SURFACE_CLUE_MAX:
        return (
            f"  warning surface pool for '{category_id}' is {pool_size} "
            f"(below SURFACE_CLUE_MAX={SURFACE_CLUE_MAX})"
        )
    return None


def _check_tier_coverage(
    category_id: str,
    anchors: list[AnchorData],
) -> list[str]:
    warnings: list[str] = []
    cat_anchors = [a for a in anchors if a.category_scope == category_id]
    if not cat_anchors:
        warnings.append(f"  warning no anchors for category '{category_id}'")
        return warnings

    tiers_with_anchors = {a.tier for a in cat_anchors}
    for t in TIER_KEYS:
        if t not in tiers_with_anchors:
            warnings.append(
                f"  warning category '{category_id}' has no tier-{t} anchors"
            )
    return warnings


def compute_clue_information(
    results: list[DrawResult],
) -> dict[str, dict[str, Any]]:
    """Compute per-clue information metrics grouped by category.

    For each clue appearing in results, measures:
      - spread_shrink: how much the p10-p90 range narrows when clue is present
      - mean_shift: how much the mean value shifts when clue is present

    Returns dict[category_id][clue_id] = { n, spread_before, spread_after,
      spread_shrink, mean_before, mean_after, mean_shift, verdict }.
    """
    clue_info: dict[str, dict[str, Any]] = {}

    by_cat: dict[str, list[DrawResult]] = defaultdict(list)
    for r in results:
        by_cat[r.category_id].append(r)

    for cat_id, cat_results in by_cat.items():
        all_values = [r.full_true_value for r in cat_results]
        spread_before = percentile(all_values, 90) - percentile(all_values, 10)
        mean_before = sum(all_values) / len(all_values)
        clue_info[cat_id] = {}

        clue_ids_in_cat: set[str] = set()
        for r in cat_results:
            clue_ids_in_cat.update(r.surface_ids)
            clue_ids_in_cat.update(r.hidden_ids)

        for clue_id in sorted(clue_ids_in_cat):
            posterior = [
                r.full_true_value
                for r in cat_results
                if clue_id in r.surface_ids or clue_id in r.hidden_ids
            ]
            n = len(posterior)
            if n == 0:
                continue

            spread_after = percentile(posterior, 90) - percentile(posterior, 10)
            spread_shrink = (
                1.0 - (spread_after / spread_before) if spread_before > 0 else 0.0
            )
            mean_after = sum(posterior) / n
            mean_shift = abs(mean_after - mean_before) / max(abs(mean_before), 1.0)

            is_low = (
                spread_shrink < LOW_INFO_SHRINK_THRESHOLD
                and mean_shift < LOW_INFO_SHIFT_THRESHOLD
            )

            clue_info[cat_id][clue_id] = {
                "n": n,
                "spread_before": spread_before,
                "spread_after": spread_after,
                "spread_shrink": spread_shrink,
                "mean_before": mean_before,
                "mean_after": mean_after,
                "mean_shift": mean_shift,
                "verdict": "low-info" if is_low else "ok",
            }

    return clue_info


def report_lot(
    lot: dict,
    results: list[DrawResult],
    clues: list[ClueData],
    anchors: list[AnchorData],
    clue_info: dict[str, dict[str, Any]] | None = None,
) -> None:
    lot_id = lot.get("lot_id", "?")

    if not results:
        print(f"\n{'='*60}")
        print(f"Lot: {lot_id}")
        print(f"  No results generated (check category/anchor configuration)")
        return

    appraised_vals = [r.appraised_value for r in results]
    full_vals = [r.full_true_value for r in results]

    print(f"\n{'='*60}")
    print(f"Lot: {lot_id}  ({len(results)} draws)")

    # Value percentiles
    print(
        f"  Appraised:  p10=${percentile(appraised_vals, 10):.0f}  "
        f"p50=${percentile(appraised_vals, 50):.0f}  "
        f"p90=${percentile(appraised_vals, 90):.0f}"
    )
    print(
        f"  Full true:  p10=${percentile(full_vals, 10):.0f}  "
        f"p50=${percentile(full_vals, 50):.0f}  "
        f"p90=${percentile(full_vals, 90):.0f}"
    )

    # Mean per tier x hidden-count cell
    cell: dict[tuple[int, int], list[float]] = defaultdict(list)
    for r in results:
        cell[(r.tier, len(r.hidden_ids))].append(r.full_true_value)
    print(f"  Mean true value per tier x hidden_count:")
    for tier in sorted(set(k[0] for k in cell)):
        parts: list[str] = []
        for hc in sorted(set(k[1] for k in cell if k[0] == tier)):
            vals = cell.get((tier, hc), [])
            if vals:
                mean_v = sum(vals) / len(vals)
                parts.append(f"    h{hc}=${mean_v:.0f}")
        if parts:
            print(f"    tier {tier}: {','.join(parts)}")

    # Surface/hidden count distributions
    surf_counter = Counter(len(r.surface_ids) for r in results)
    hid_counter = Counter(len(r.hidden_ids) for r in results)
    print(f"  Surface count dist: {dict(sorted(surf_counter.items()))}")
    print(f"  Hidden count dist:  {dict(sorted(hid_counter.items()))}")

    # Per-clue information
    if clue_info:
        for cat_id in sorted(clue_info):
            cat_clues = clue_info[cat_id]
            if not cat_clues:
                continue
            clue_ids = sorted(cat_clues.keys())
            max_id_len = max(len(cid) for cid in clue_ids)
            id_col = max(max_id_len, 8)

            print(f"\n  Clue information, category={cat_id}:")
            print(
                f"    {'clue_id':<{id_col}}  {'n':>4}  {'shrink':>7}"
                f"  {'mean_shift':>7}  verdict"
            )
            for clue_id in clue_ids:
                info = cat_clues[clue_id]
                print(
                    f"    {clue_id:<{id_col}}  {info['n']:>4}"
                    f"  {info['spread_shrink']:>7.2f}"
                    f"  {info['mean_shift']:>+7.2f}"
                    f"  {info['verdict']}"
                )

    # Content-health flags
    seen_categories: set[str] = set()
    for r in results:
        seen_categories.add(r.category_id)
    for cat_id in lot.get("category_weights", {}) or {}:
        seen_categories.add(cat_id)

    has_warnings = False
    for cat_id in sorted(seen_categories):
        w = _check_surface_pool(cat_id, clues)
        if w:
            if not has_warnings:
                print()
                has_warnings = True
            print(f"{YELLOW}{w}{RESET}")
        for tw in _check_tier_coverage(cat_id, anchors):
            if not has_warnings:
                print()
                has_warnings = True
            print(f"{YELLOW}{tw}{RESET}")


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    ap = argparse.ArgumentParser(description="Pool-generation balance preview tool.")
    ap.add_argument("--yaml-dir", required=True, help="Path to data/yaml directory")
    ap.add_argument(
        "--samples",
        type=int,
        default=10_000,
        help="Number of draws per lot (default 10000)",
    )
    ap.add_argument("--seed", type=int, default=0, help="Random seed (0=no seed)")
    ap.add_argument("--json", help="Output path for JSON dump")
    ap.add_argument("--lot-id", help="Only simulate this lot_id")
    args = ap.parse_args()

    yaml_dir = Path(args.yaml_dir)
    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    rng = random.Random(args.seed if args.seed != 0 else None)

    print("Loading YAML sources...")
    categories = load_categories(yaml_dir)
    anchors, clues = load_anchors_and_clues(yaml_dir)
    affixes, combinations = load_affixes(yaml_dir)
    lots = load_lots(yaml_dir)
    print(f"  Categories: {len(categories)}")
    print(f"  Anchors: {len(anchors)}")
    print(f"  Clues: {len(clues)}")
    print(f"  Affixes: {len(affixes)}")
    print(f"  Combinations: {len(combinations)}")
    print(f"  Lots: {len(lots)}")

    all_data: dict[str, Any] = {}

    for lot in lots:
        lot_id = lot.get("lot_id", "?")
        if args.lot_id and lot_id != args.lot_id:
            continue

        results = simulate_lot(
            lot,
            categories,
            anchors,
            clues,
            affixes,
            combinations,
            args.samples,
            rng,
        )
        clue_info = compute_clue_information(results)
        report_lot(lot, results, clues, anchors, clue_info)

        if args.json:
            appraised_vals = [r.appraised_value for r in results]
            full_vals = [r.full_true_value for r in results]
            all_data[lot_id] = {
                "samples": len(results),
                "appraised_p10": percentile(appraised_vals, 10),
                "appraised_p50": percentile(appraised_vals, 50),
                "appraised_p90": percentile(appraised_vals, 90),
                "verified_p10": percentile(full_vals, 10),
                "verified_p50": percentile(full_vals, 50),
                "verified_p90": percentile(full_vals, 90),
                "surface_dist": dict(Counter(len(r.surface_ids) for r in results)),
                "hidden_dist": dict(Counter(len(r.hidden_ids) for r in results)),
                "clue_info": clue_info,
            }

    if args.json:
        with open(args.json, "w") as f:
            json.dump(all_data, f, indent=2)
        print(f"\nJSON written to {args.json}")


if __name__ == "__main__":
    main()
