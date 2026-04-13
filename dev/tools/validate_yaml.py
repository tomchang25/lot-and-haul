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


def _validate_merchants(merchants: list, known_super_cat_ids: set[str]) -> list[str]:
    """Validate merchant entries."""
    errors: list[str] = []
    seen_ids: set[str] = set()

    for merchant in merchants:
        mid = merchant.get("merchant_id", "")
        if not mid:
            errors.append("Merchant missing merchant_id")
            continue
        if mid in seen_ids:
            errors.append(f"Duplicate merchant_id: '{mid}'")
        seen_ids.add(mid)

        if not merchant.get("display_name"):
            errors.append(f"merchant '{mid}': missing display_name")

        price_mult = merchant.get("price_multiplier", 1.0)
        if not isinstance(price_mult, (int, float)) or price_mult <= 0:
            errors.append(
                f"merchant '{mid}': price_multiplier must be positive,"
                f" got {price_mult!r}"
            )

        off_cat_mult = merchant.get("off_category_multiplier", 0.5)
        if not isinstance(off_cat_mult, (int, float)) or off_cat_mult < 0:
            errors.append(
                f"merchant '{mid}': off_category_multiplier must be non-negative,"
                f" got {off_cat_mult!r}"
            )

        accept_chance = merchant.get("accept_base_chance", 0.8)
        if not isinstance(accept_chance, (int, float)) or not (0.0 <= accept_chance <= 1.0):
            errors.append(
                f"merchant '{mid}': accept_base_chance must be between 0.0 and 1.0,"
                f" got {accept_chance!r}"
            )

        # Validate accepted_super_categories references
        if known_super_cat_ids:
            for sc in merchant.get("accepted_super_categories", []) or []:
                sc_id = str(sc).lower().replace(" ", "_")
                if sc_id not in known_super_cat_ids:
                    errors.append(
                        f"merchant '{mid}': accepted_super_category '{sc}'"
                        f" not defined in super_categories"
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

    # Build known super_category_ids from the raw super_categories list
    known_super_cat_ids: set[str] = {
        str(s).lower().replace(" ", "_")
        for s in data.get("super_categories", [])
    }
    errors.extend(
        _validate_merchants(data.get("merchants", []), known_super_cat_ids)
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
        "merchants": [],
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
