"""
validate_yaml.py
Validate merged YAML data for the lot-and-haul data pipeline.

Can be used standalone (for CI, pre-commit hooks, or authoring-time checks)
or imported by yaml_to_tres.py as part of the full TRES generation pipeline.

Usage:
    python validate_yaml.py --yaml-dir path/to/data/yaml
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── Constants ────────────────────────────────────────────────────────────────


_VALID_SHAPE_IDS: frozenset[str] = frozenset(
    {
        "s1x1",
        "s1x2",
        "s1x3",
        "s1x4",
        "s2x2",
        "s2x3",
        "s2x4",
        "sL11",
        "sL12",
        "sT3",
    }
)


# ── Per-entity validators ────────────────────────────────────────────────────


def _validate_skills(skills: list) -> tuple[list[str], set[str]]:
    """Validate skill entries. Returns (errors, known_skill_ids)."""
    errors: list[str] = []
    seen_skill_ids: set[str] = set()

    for skill in skills:
        sid = skill.get("skill_id", "")
        if not sid:
            errors.append("Skill missing skill_id")
            continue
        if sid in seen_skill_ids:
            errors.append(f"Duplicate skill_id: '{sid}'")
        seen_skill_ids.add(sid)

        if not skill.get("display_name"):
            errors.append(f"Skill '{sid}': missing display_name")

        levels = skill.get("levels", [])
        if not levels:
            errors.append(f"Skill '{sid}': no levels defined")
            continue

        for i, level in enumerate(levels):
            if "cash_cost" not in level:
                errors.append(f"Skill '{sid}' level {i}: missing cash_cost")
            elif not isinstance(level["cash_cost"], int) or level["cash_cost"] < 0:
                errors.append(
                    f"Skill '{sid}' level {i}: cash_cost must be a non-negative integer"
                )

            ranks = level.get("required_super_category_ranks", {})
            if ranks is not None and not isinstance(ranks, dict):
                errors.append(
                    f"Skill '{sid}' level {i}: required_super_category_ranks must be a dict"
                )

    return errors, set(seen_skill_ids)


def _validate_categories(categories: list) -> tuple[list[str], set[str]]:
    """Validate category entries. Returns (errors, known_category_ids)."""
    errors: list[str] = []
    known_cat_ids: set[str] = {c["category_id"] for c in categories}

    for cat in categories:
        cid = cat.get("category_id", "?")
        shape_id = cat.get("shape_id")
        if shape_id is None:
            errors.append(f"category '{cid}': missing shape_id")
        elif shape_id not in _VALID_SHAPE_IDS:
            errors.append(
                f"category '{cid}': unknown shape_id '{shape_id}'"
                f" — valid: {sorted(_VALID_SHAPE_IDS)}"
            )

    return errors, known_cat_ids


def _validate_identity_layers(
    layers: list, known_skill_ids: set[str]
) -> tuple[list[str], set[str]]:
    """Validate identity layer entries. Returns (errors, known_layer_ids)."""
    errors: list[str] = []
    known_layer_ids: set[str] = {l["layer_id"] for l in layers}

    for layer in layers:
        lid = layer.get("layer_id", "?")
        unlock = layer.get("unlock_action")

        if unlock is None:
            continue  # final layer — OK

        ctx = unlock.get("context")
        if ctx not in (0, 1):
            errors.append(
                f"layer '{lid}': unlock_action.context must be 0 or 1, got {ctx!r}"
            )

        if ctx == 1 and not unlock.get("unlock_days"):
            errors.append(f"layer '{lid}': context=1 (HOME) requires unlock_days >= 1")

        sid = unlock.get("required_skill")
        if sid and known_skill_ids and sid not in known_skill_ids:
            errors.append(f"layer '{lid}': unknown required_skill '{sid}'")

    return errors, known_layer_ids


def _validate_items(
    items: list,
    layers: list,
    known_cat_ids: set[str],
    known_layer_ids: set[str],
) -> list[str]:
    """Validate item entries."""
    errors: list[str] = []

    for item in items:
        iid = item.get("item_id", "?")
        layer_ids = item.get("layer_ids", [])

        if item.get("category_id") not in known_cat_ids:
            errors.append(
                f"item '{iid}': category_id '{item.get('category_id')}' not defined"
            )

        if len(layer_ids) < 2:
            errors.append(f"item '{iid}': must have at least 2 layer_ids")

        for lid in layer_ids:
            if lid not in known_layer_ids:
                errors.append(
                    f"item '{iid}': layer_id '{lid}' not defined in identity_layers"
                )

        if layer_ids:
            first = next(
                (l for l in layers if l["layer_id"] == layer_ids[0]),
                None,
            )
            if first:
                ctx0 = (first.get("unlock_action") or {}).get("context")
                if ctx0 != 0:
                    errors.append(
                        f"item '{iid}': layer[0] '{layer_ids[0]}' must have context=0 (AUTO)"
                    )

            last = next(
                (l for l in layers if l["layer_id"] == layer_ids[-1]),
                None,
            )
            if last and last.get("unlock_action") is not None:
                errors.append(
                    f"item '{iid}': final layer '{layer_ids[-1]}' must have unlock_action: null"
                )

            # Position-aware checks along the item's layer chain.
            prev_base_value: int | None = None
            for index, lid in enumerate(layer_ids):
                layer = next(
                    (l for l in layers if l["layer_id"] == lid),
                    None,
                )
                if layer is None:
                    continue

                unlock = layer.get("unlock_action")

                if index < len(layer_ids) - 1 and unlock is None:
                    errors.append(
                        f"item '{iid}': layer[{index}] '{lid}' has no unlock_action"
                        f" but is not the final layer"
                    )

                if index >= 1 and unlock is not None and unlock.get("context") == 0:
                    errors.append(
                        f"item '{iid}': layer[{index}] '{lid}' uses context=0 (AUTO)"
                        f" but only layer[0] may be AUTO"
                    )

                cur_base_value = layer.get("base_value")
                if (
                    prev_base_value is not None
                    and cur_base_value is not None
                    and cur_base_value <= prev_base_value
                ):
                    errors.append(
                        f"item '{iid}': layer[{index}] '{lid}' base_value"
                        f" {cur_base_value} is not greater than previous layer's"
                        f" {prev_base_value}"
                    )
                if cur_base_value is not None:
                    prev_base_value = cur_base_value

    return errors


def _validate_cars(cars: list) -> list[str]:
    """Validate car entries."""
    errors: list[str] = []
    seen_car_ids: set[str] = set()

    for car in cars:
        car_id = car.get("car_id", "")
        if not car_id:
            errors.append("Car missing car_id")
            continue
        if car_id in seen_car_ids:
            errors.append(f"Duplicate car_id: '{car_id}'")
        seen_car_ids.add(car_id)

        grid_columns = car.get("grid_columns")
        if not isinstance(grid_columns, int) or grid_columns <= 0:
            errors.append(
                f"car '{car_id}': grid_columns must be a positive integer,"
                f" got {grid_columns!r}"
            )

        grid_rows = car.get("grid_rows")
        if not isinstance(grid_rows, int) or grid_rows <= 0:
            errors.append(
                f"car '{car_id}': grid_rows must be a positive integer,"
                f" got {grid_rows!r}"
            )

        max_weight = car.get("max_weight")
        if not isinstance(max_weight, (int, float)) or max_weight <= 0:
            errors.append(
                f"car '{car_id}': max_weight must be a positive number,"
                f" got {max_weight!r}"
            )

        stamina_cap = car.get("stamina_cap")
        if not isinstance(stamina_cap, int) or stamina_cap <= 0:
            errors.append(
                f"car '{car_id}': stamina_cap must be a positive integer,"
                f" got {stamina_cap!r}"
            )

        fuel_cost_per_day = car.get("fuel_cost_per_day", 0)
        if not isinstance(fuel_cost_per_day, int) or fuel_cost_per_day < 0:
            errors.append(
                f"car '{car_id}': fuel_cost_per_day must be a non-negative"
                f" integer, got {fuel_cost_per_day!r}"
            )

        extra_slot_count = car.get("extra_slot_count", 0)
        if not isinstance(extra_slot_count, int) or extra_slot_count < 0:
            errors.append(
                f"car '{car_id}': extra_slot_count must be a non-negative"
                f" integer, got {extra_slot_count!r}"
            )

    return errors


def _validate_lots(lots: list) -> tuple[list[str], set[str]]:
    """Validate lot entries. Returns (errors, known_lot_ids)."""
    errors: list[str] = []
    seen_lot_ids: set[str] = set()

    _RANGE_PAIRS: list[tuple[str, str]] = [
        ("aggressive_factor_min", "aggressive_factor_max"),
        ("aggressive_lerp_min", "aggressive_lerp_max"),
        ("item_count_min", "item_count_max"),
        ("price_floor_factor", "price_ceiling_factor"),
        ("price_variance_min", "price_variance_max"),
    ]

    for lot in lots:
        lid = lot.get("lot_id", "")
        if not lid:
            errors.append("Lot missing lot_id")
            continue
        if lid in seen_lot_ids:
            errors.append(f"Duplicate lot_id: '{lid}'")
        seen_lot_ids.add(lid)

        for lo_key, hi_key in _RANGE_PAIRS:
            lo = lot.get(lo_key)
            hi = lot.get(hi_key)
            if (
                lo is not None
                and hi is not None
                and isinstance(lo, (int, float))
                and isinstance(hi, (int, float))
                and lo > hi
            ):
                errors.append(
                    f"lot '{lid}': {lo_key} ({lo}) must be <= {hi_key} ({hi})"
                )

        item_count_min = lot.get("item_count_min", 3)
        if not isinstance(item_count_min, int) or item_count_min < 1:
            errors.append(
                f"lot '{lid}': item_count_min must be a positive integer,"
                f" got {item_count_min!r}"
            )

        action_quota = lot.get("action_quota", 6)
        if not isinstance(action_quota, int) or action_quota < 1:
            errors.append(
                f"lot '{lid}': action_quota must be a positive integer,"
                f" got {action_quota!r}"
            )

        rarity_weights = lot.get("rarity_weights", {})
        if rarity_weights is not None and not isinstance(rarity_weights, dict):
            errors.append(
                f"lot '{lid}': rarity_weights must be a dict,"
                f" got {type(rarity_weights).__name__}"
            )

        cat_w = lot.get("category_weights", {}) or {}
        super_w = lot.get("super_category_weights", {}) or {}
        if not cat_w and not super_w:
            errors.append(
                f"lot '{lid}': at least one of category_weights or"
                f" super_category_weights must be non-empty"
            )

    return errors, set(seen_lot_ids)


def _validate_locations(
    locations: list, known_lot_ids: set[str]
) -> list[str]:
    """Validate location entries."""
    errors: list[str] = []
    seen_location_ids: set[str] = set()

    for loc in locations:
        loc_id = loc.get("location_id", "")
        if not loc_id:
            errors.append("Location missing location_id")
            continue
        if loc_id in seen_location_ids:
            errors.append(f"Duplicate location_id: '{loc_id}'")
        seen_location_ids.add(loc_id)

        if not loc.get("display_name"):
            errors.append(f"location '{loc_id}': missing display_name")

        entry_fee = loc.get("entry_fee", 0)
        if not isinstance(entry_fee, int) or entry_fee < 0:
            errors.append(
                f"location '{loc_id}': entry_fee must be a non-negative"
                f" integer, got {entry_fee!r}"
            )

        travel_days = loc.get("travel_days", 1)
        if not isinstance(travel_days, int) or travel_days < 1:
            errors.append(
                f"location '{loc_id}': travel_days must be a positive"
                f" integer, got {travel_days!r}"
            )

        lot_number = loc.get("lot_number", 3)
        if not isinstance(lot_number, int) or lot_number < 1:
            errors.append(
                f"location '{loc_id}': lot_number must be a positive"
                f" integer, got {lot_number!r}"
            )

        lot_pool = loc.get("lot_pool", []) or []
        if not lot_pool:
            errors.append(f"location '{loc_id}': lot_pool must be non-empty")
        else:
            if len(lot_pool) < lot_number:
                errors.append(
                    f"location '{loc_id}': lot_pool has {len(lot_pool)}"
                    f" lot(s) but lot_number is {lot_number}"
                )
            for ref in lot_pool:
                if ref not in known_lot_ids:
                    errors.append(
                        f"location '{loc_id}': lot_pool references"
                        f" unknown lot_id '{ref}'"
                    )

    return errors


# ── Public API ───────────────────────────────────────────────────────────────


def validate(data: dict) -> list[str]:
    """Validate merged YAML data. Returns list of error strings.
    Empty list means OK."""
    errors: list[str] = []

    skill_errors, known_skill_ids = _validate_skills(data.get("skills", []))
    errors.extend(skill_errors)

    cat_errors, known_cat_ids = _validate_categories(data.get("categories", []))
    errors.extend(cat_errors)

    layer_errors, known_layer_ids = _validate_identity_layers(
        data.get("identity_layers", []), known_skill_ids
    )
    errors.extend(layer_errors)

    errors.extend(
        _validate_items(
            data.get("items", []),
            data.get("identity_layers", []),
            known_cat_ids,
            known_layer_ids,
        )
    )

    errors.extend(_validate_cars(data.get("cars", [])))

    lot_errors, known_lot_ids = _validate_lots(data.get("lots", []))
    errors.extend(lot_errors)

    errors.extend(
        _validate_locations(data.get("locations", []), known_lot_ids)
    )

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

    yaml_files = sorted(yaml_dir.glob("*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {
        "skills": [],
        "super_categories": [],
        "categories": [],
        "identity_layers": [],
        "items": [],
        "cars": [],
        "lots": [],
        "locations": [],
    }

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    print("Validating...")
    errors = validate(merged)
    if errors:
        print(f"  {len(errors)} error(s) found:")
        for e in errors:
            print(f"    \u2717 {e}")
        sys.exit(1)
    print("  OK")


if __name__ == "__main__":
    main()
