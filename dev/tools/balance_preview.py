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
RARITY_KEYS = [0, 1, 2, 3, 4]  # COMMON through LEGENDARY
TIER_KEYS = [1, 2, 3, 4, 5]


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

    # Fall back to nearest tier, preferring lower on ties
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


def draw_surface_clues(
    category_id: str,
    count: int,
    clues: list[ClueData],
    rng: random.Random,
) -> list[ClueData]:
    """Draw surface clues. See ItemGenerator._draw_surface_clues."""
    pool = [
        c
        for c in clues
        if c.type == "surface" and (c.domain == "generic" or c.domain == category_id)
    ]
    actual = min(count, len(pool))
    if actual == 0:
        return []
    return rng.sample(pool, actual)


def pick_rarity(
    rarity_weights: dict[int, int], rng: random.Random
) -> int:
    """Pick rarity from weighted table. See ItemGenerator._pick_rarity."""
    if not rarity_weights:
        return 0
    keys = list(rarity_weights.keys())
    vals = [rarity_weights[k] for k in keys]
    idx = pick_weighted_index(vals, rng)
    if idx < 0:
        return 0
    return keys[idx]


def draw_hidden_clues(
    category_id: str,
    count: int,
    clues: list[ClueData],
    rng: random.Random,
) -> list[ClueData]:
    """Draw hidden clues with constraints. See ItemGenerator._draw_hidden_clues."""
    if count <= 0:
        return []

    pool = [
        c
        for c in clues
        if c.type == "hidden" and (c.domain == "generic" or c.domain == category_id)
    ]
    if not pool:
        return []

    rng.shuffle(pool)

    chosen: list[ClueData] = []
    used_groups: set[str] = set()
    has_override = False

    for c in pool:
        if len(chosen) >= count:
            break
        if c.exclusive_group and c.exclusive_group in used_groups:
            continue
        if c.effect_op == "override":
            if has_override:
                continue
            has_override = True
        chosen.append(c)
        if c.exclusive_group:
            used_groups.add(c.exclusive_group)

    return chosen


# ── Price pipeline (mirroring ItemEntry) ──────────────────────────────────────


def compute_appraised_value(anchor: AnchorData, surface_clues: list[ClueData]) -> float:
    """Compute appraised value: (anchor.base_value + sum_add) * prod_mul."""
    add_sum = 0.0
    mul_prod = 1.0
    for c in surface_clues:
        if c.effect_op == "add":
            add_sum += c.effect_amount
        elif c.effect_op == "mul":
            mul_prod *= c.effect_amount
    return (anchor.base_value + add_sum) * mul_prod


def compute_verified_value(
    anchor: AnchorData,
    surface_clues: list[ClueData],
    hidden_clues: list[ClueData],
) -> float:
    """Compute verified value with hidden clues."""
    # Effective base: override or anchor
    base = anchor.base_value
    for c in hidden_clues:
        if c.effect_op == "override":
            base = c.effect_amount
            break

    add_sum = 0.0
    mul_prod = 1.0
    for c in surface_clues + hidden_clues:
        if c.effect_op == "add":
            add_sum += c.effect_amount
        elif c.effect_op == "mul":
            mul_prod *= c.effect_amount
    return (base + add_sum) * mul_prod


# ── Simulation ────────────────────────────────────────────────────────────────


@dataclass
class DrawResult:
    appraised: float
    verified: float
    surface_count: int
    hidden_count: int
    rarity: int
    tier: int
    anchor_id: str


def simulate_lot(
    lot: dict,
    categories: dict[str, CategoryData],
    anchors: list[AnchorData],
    clues: list[ClueData],
    samples: int,
    rng: random.Random,
) -> list[DrawResult]:
    """Simulate N item draws for a given lot configuration."""
    tier_weights = {int(k): int(v) for k, v in lot.get("tier_weights", {}).items()}
    rarity_weights = {int(k): int(v) for k, v in lot.get("rarity_weights", {}).items()}
    cat_weights: dict[str, int] = lot.get("category_weights", {}) or {}
    sc_weights: dict[str, int] = lot.get("super_category_weights", {}) or {}

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

        # Draw surface clues
        surface_count = rng.randint(
            max(SURFACE_CLUE_MIN, HARD_SURFACE_MIN),
            min(SURFACE_CLUE_MAX, HARD_SURFACE_MAX),
        )
        surface = draw_surface_clues(category_id, surface_count, clues, rng)

        # Draw rarity and hidden clues
        rarity = pick_rarity(rarity_weights, rng)
        hidden = draw_hidden_clues(category_id, rarity, clues, rng)
        effective_rarity = len(hidden)

        result = DrawResult(
            appraised=compute_appraised_value(anchor, surface),
            verified=compute_verified_value(anchor, surface, hidden),
            surface_count=len(surface),
            hidden_count=effective_rarity,
            rarity=effective_rarity,
            tier=anchor.tier,
            anchor_id=anchor.anchor_id,
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
    # Build super-category → member categories mapping from loaded categories
    # Super-category membership is via the super_category field on CategoryData
    if sc_weights:
        sc_keys = list(sc_weights.keys())
        sc_vals = [sc_weights[k] for k in sc_keys]
        idx = pick_weighted_index(sc_vals, rng)
        if idx < 0:
            return None
        sc_id = sc_keys[idx]
        # Find member categories for this super-category
        members = [
            cid
            for cid, cat in categories.items()
            if cat.super_category == sc_id
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
            f"  ⚠ surface pool for '{category_id}' is {pool_size} "
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
        warnings.append(f"  ⚠ no anchors for category '{category_id}'")
        return warnings

    tiers_with_anchors = {a.tier for a in cat_anchors}
    for t in TIER_KEYS:
        if t not in tiers_with_anchors:
            warnings.append(f"  ⚠ category '{category_id}' has no tier-{t} anchors")
    return warnings


def _check_hidden_pool_depth(
    category_id: str,
    clues: list[ClueData],
) -> list[str]:
    warnings: list[str] = []
    hidden_pool = [
        c
        for c in clues
        if c.type == "hidden" and (c.domain == "generic" or c.domain == category_id)
    ]
    for r in range(1, 5):
        # Count available clues that respect constraints (simplified: just count, ignoring exclusive_group overlap)
        # Estimate: each exclusive_group reduces effective pool by (group_size - 1)
        groups: dict[str, int] = {}
        n_override = 0
        for c in hidden_pool:
            if c.exclusive_group:
                groups[c.exclusive_group] = groups.get(c.exclusive_group, 0) + 1
            if c.effect_op == "override":
                n_override += 1

        effective = len(hidden_pool)
        for g, size in groups.items():
            effective -= size - 1  # only 1 per group
        # at most 1 override
        effective = max(1, effective - max(0, n_override - 1))

        if effective < r:
            warnings.append(
                f"  ⚠ category '{category_id}' cannot reach rarity {r} "
                f"(effective hidden pool={effective})"
            )
    return warnings


def report_lot(
    lot: dict,
    results: list[DrawResult],
    clues: list[ClueData],
    anchors: list[AnchorData],
) -> None:
    lot_id = lot.get("lot_id", "?")

    if not results:
        print(f"\n{'='*60}")
        print(f"Lot: {lot_id}")
        print(f"  No results generated (check category/anchor configuration)")
        return

    appraised_vals = [r.appraised for r in results]
    verified_vals = [r.verified for r in results]

    print(f"\n{'='*60}")
    print(f"Lot: {lot_id}  ({len(results)} draws)")

    # Value percentiles
    print(f"  Appraised:  p10=${percentile(appraised_vals, 10):.0f}  "
          f"p50=${percentile(appraised_vals, 50):.0f}  "
          f"p90=${percentile(appraised_vals, 90):.0f}")
    print(f"  Verified:   p10=${percentile(verified_vals, 10):.0f}  "
          f"p50=${percentile(verified_vals, 50):.0f}  "
          f"p90=${percentile(verified_vals, 90):.0f}")

    # Mean per tier x rarity cell
    cell: dict[tuple[int, int], list[float]] = defaultdict(list)
    for r in results:
        cell[(r.tier, r.rarity)].append(r.verified)
    print(f"  Mean verified per tier×rarity:")
    for tier in sorted(set(k[0] for k in cell)):
        parts: list[str] = []
        for rarity in RARITY_KEYS:
            vals = cell.get((tier, rarity), [])
            if vals:
                mean_v = sum(vals) / len(vals)
                parts.append(f"    r{rarity}=${mean_v:.0f}")
            else:
                parts.append(f"    r{rarity}=—")
        print(f"    tier {tier}: {','.join(parts)}")

    # Surface/hidden count distributions
    surf_counter = Counter(r.surface_count for r in results)
    hid_counter = Counter(r.hidden_count for r in results)
    print(f"  Surface count dist: {dict(sorted(surf_counter.items()))}")
    print(f"  Hidden count dist:  {dict(sorted(hid_counter.items()))}")

    # Content-health flags
    seen_categories: set[str] = set()
    for r in results:
        for clue in clues:
            if clue.domain != "generic" and clue.domain not in seen_categories:
                seen_categories.add(clue.domain)
    # Also check from lot's category_weights
    for cat_id in (lot.get("category_weights", {}) or {}):
        seen_categories.add(cat_id)

    for cat_id in sorted(seen_categories):
        w = _check_surface_pool(cat_id, clues)
        if w:
            print(w)
        for tw in _check_tier_coverage(cat_id, anchors):
            print(tw)
        for hw in _check_hidden_pool_depth(cat_id, clues):
            print(hw)


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    ap = argparse.ArgumentParser(description="Pool-generation balance preview tool.")
    ap.add_argument("--yaml-dir", required=True, help="Path to data/yaml directory")
    ap.add_argument("--samples", type=int, default=10_000, help="Number of draws per lot (default 10000)")
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
    lots = load_lots(yaml_dir)
    print(f"  Categories: {len(categories)}")
    print(f"  Anchors: {len(anchors)}")
    print(f"  Clues: {len(clues)}")
    print(f"  Lots: {len(lots)}")

    all_data: dict[str, Any] = {}

    for lot in lots:
        lot_id = lot.get("lot_id", "?")
        if args.lot_id and lot_id != args.lot_id:
            continue

        results = simulate_lot(lot, categories, anchors, clues, args.samples, rng)
        report_lot(lot, results, clues, anchors)

        if args.json:
            appraised_vals = [r.appraised for r in results]
            verified_vals = [r.verified for r in results]
            all_data[lot_id] = {
                "samples": len(results),
                "appraised_p10": percentile(appraised_vals, 10),
                "appraised_p50": percentile(appraised_vals, 50),
                "appraised_p90": percentile(appraised_vals, 90),
                "verified_p10": percentile(verified_vals, 10),
                "verified_p50": percentile(verified_vals, 50),
                "verified_p90": percentile(verified_vals, 90),
                "surface_dist": dict(Counter(r.surface_count for r in results)),
                "hidden_dist": dict(Counter(r.hidden_count for r in results)),
            }

    if args.json:
        with open(args.json, "w") as f:
            json.dump(all_data, f, indent=2)
        print(f"\nJSON written to {args.json}")


if __name__ == "__main__":
    main()
