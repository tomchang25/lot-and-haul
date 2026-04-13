"""
yaml_to_tres.py
Write SkillData, SuperCategoryData, CategoryData, IdentityLayer, ItemData, and
CarData .tres files directly from YAML source files, without an intermediate
database.

Resource UIDs are derived deterministically from each entity's (type, id) pair
via SHA-256, so regenerating from YAML produces byte-identical output even with
no existing .tres files on disk.

Script UIDs for the referenced .gd classes are read at runtime from their
Godot sidecar files (e.g. data/definitions/item_data.gd.uid), so Godot can
regenerate them freely without silently breaking this tool.

Usage:
    python yaml_to_tres.py --godot-root /path/to/godot/project
    python yaml_to_tres.py --godot-root /path/to/godot/project --dry-run
    python yaml_to_tres.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import hashlib
import string
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from validate_yaml import validate


# ── UID helpers ───────────────────────────────────────────────────────────────

_UID_CHARS = string.ascii_lowercase + string.digits


def _deterministic_uid(entity_type: str, entity_id: str) -> str:
    """Stable uid://... for an (entity_type, entity_id) pair.

    Using a prefix ensures two entities with the same id but different types
    (e.g. skill:appraisal vs category:appraisal) get distinct UIDs.
    """
    digest = hashlib.sha256(f"{entity_type}:{entity_id}".encode()).digest()
    chars = "".join(_UID_CHARS[b % 36] for b in digest[:12])
    return "uid://" + chars


# ── Script paths ──────────────────────────────────────────────────────────────
#
# UIDs for these scripts are read at runtime from their .gd.uid sidecar files
# (see _read_script_uid). Keep these paths in sync with the actual .gd files.

_ITEM_DATA_SCRIPT_PATH = "res://data/definitions/item_data.gd"
_IDENTITY_LAYER_SCRIPT_PATH = "res://data/definitions/identity_layer.gd"
_LAYER_UNLOCK_SCRIPT_PATH = "res://data/definitions/layer_unlock_action.gd"
_CATEGORY_DATA_SCRIPT_PATH = "res://data/definitions/category_data.gd"
_SUPER_CATEGORY_DATA_SCRIPT_PATH = "res://data/definitions/super_category_data.gd"
_SKILL_DATA_SCRIPT_PATH = "res://data/definitions/skill_data.gd"
_SKILL_LEVEL_DATA_SCRIPT_PATH = "res://data/definitions/skill_level_data.gd"
_CAR_DATA_SCRIPT_PATH = "res://data/definitions/car_data.gd"


def _read_script_uid(godot_root: Path, res_path: str) -> str:
    """Read a script's UID from its Godot .gd.uid sidecar file.

    ``res_path`` is a Godot resource path like
    ``res://data/definitions/item_data.gd``. The sidecar is expected at the
    same filesystem location with a trailing ``.uid`` suffix.
    """
    if not res_path.startswith("res://"):
        sys.exit(f"Script path must start with 'res://': {res_path}")
    rel = res_path[len("res://") :]
    sidecar = godot_root / (rel + ".uid")
    if not sidecar.is_file():
        sys.exit(f"Script UID sidecar not found: {sidecar}")
    content = sidecar.read_text(encoding="utf-8").strip()
    if not content.startswith("uid://"):
        sys.exit(f"Script UID sidecar malformed (expected 'uid://...'): {sidecar}")
    return content


# ── .tres builders ────────────────────────────────────────────────────────────


def _format_dict(d: dict) -> str:
    """Format a Python dict as a Godot Dictionary literal."""
    if not d:
        return "{}"
    pairs = ", ".join(f'"{k}": {v}' for k, v in sorted(d.items()))
    return "{ " + pairs + " }"


def _build_skill_tres(
    skill_id: str,
    resource_uid: str,
    display_name: str,
    levels: list[dict],
    skill_data_script_uid: str,
    skill_level_data_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="SkillData" format=3 uid="{resource_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{skill_data_script_uid}" '
        f'path="res://data/definitions/skill_data.gd" id="1_skill"]',
        f'[ext_resource type="Script" uid="{skill_level_data_script_uid}" '
        f'path="res://data/definitions/skill_level_data.gd" id="2_lvl"]',
    ]

    for i, level in enumerate(levels):
        ranks = level.get("required_super_category_ranks", {}) or {}
        lines += [
            "",
            f'[sub_resource type="Resource" id="lvl_{i}"]',
            'script = ExtResource("2_lvl")',
            f'cash_cost = {int(level["cash_cost"])}',
            f'required_mastery_rank = {int(level.get("required_mastery_rank", 0))}',
            f"required_super_category_ranks = {_format_dict(ranks)}",
        ]

    level_refs = ", ".join(f'SubResource("lvl_{i}")' for i in range(len(levels)))

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_skill")',
        f'skill_id = "{skill_id}"',
        f'display_name = "{display_name}"',
        f"levels = [{level_refs}]",
        "",
    ]
    return "\n".join(lines)


def _build_super_category_tres(
    super_category_id: str,
    super_category_uid: str,
    display_name: str,
    super_category_data_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="SuperCategoryData" format=3 uid="{super_category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{super_category_data_script_uid}" '
        f'path="res://data/definitions/super_category_data.gd" id="1_superdef"]',
        "",
        "[resource]",
        'script = ExtResource("1_superdef")',
        f'super_category_id = "{super_category_id}"',
        f'display_name = "{display_name}"',
        "",
    ]
    return "\n".join(lines)


def _build_category_tres(
    category_id: str,
    category_uid: str,
    super_category_id: str,
    super_category_uid: str,
    display_name: str,
    weight: float,
    shape_id: str,
    category_data_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="CategoryData" format=3 uid="{category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{category_data_script_uid}" '
        f'path="res://data/definitions/category_data.gd" id="1_catdef"]',
        f'[ext_resource type="Resource" uid="{super_category_uid}" '
        f'path="res://data/tres/super_categories/{super_category_id}.tres" id="2_super"]',
        "",
        "[resource]",
        'script = ExtResource("1_catdef")',
        f'category_id = "{category_id}"',
        'super_category = ExtResource("2_super")',
        f'display_name = "{display_name}"',
        f"weight = {float(weight)}",
        f'shape_id = "{shape_id}"',
        "",
    ]
    return "\n".join(lines)


def _build_layer_tres(
    layer_id: str,
    layer_uid: str,
    display_name: str,
    base_value: int,
    unlock: dict | None,
    uid_cache: dict[str, str],
    identity_layer_script_uid: str,
    layer_unlock_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="IdentityLayer" format=3 uid="{layer_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{identity_layer_script_uid}" '
        f'path="res://data/definitions/identity_layer.gd" id="1_ilay"]',
    ]

    if unlock is not None:
        lines.append(
            f'[ext_resource type="Script" uid="{layer_unlock_script_uid}" '
            f'path="res://data/definitions/layer_unlock_action.gd" id="2_unlock"]'
        )

        skill_tag: str | None = None
        sid = unlock.get("required_skill")
        if sid:
            suid = uid_cache.get(sid)
            if suid:
                lines.append(
                    f'[ext_resource type="Resource" uid="{suid}" '
                    f'path="res://data/tres/skills/{sid}.tres" id="3_skill"]'
                )
                skill_tag = "3_skill"

        skill_ref = f'ExtResource("{skill_tag}")' if skill_tag else "null"
        lines += [
            "",
            '[sub_resource type="Resource" id="unlock"]',
            'script = ExtResource("2_unlock")',
            f'context = {int(unlock["context"])}',
            f'unlock_days = {int(unlock.get("unlock_days", 0))}',
        ]
        if skill_tag:
            lines += [
                f"required_skill = {skill_ref}",
                f'required_level = {int(unlock.get("required_level", 0))}',
            ]
        if float(unlock.get("required_condition", 0.0)) != 0.0:
            lines.append(f'required_condition = {float(unlock["required_condition"])}')
        if int(unlock.get("required_category_rank", 0)) != 0:
            lines.append(
                f'required_category_rank = {int(unlock["required_category_rank"])}'
            )
        if unlock.get("required_perk_id", ""):
            lines.append(f'required_perk_id = "{unlock["required_perk_id"]}"')
        lines.append("")

    unlock_ref = 'SubResource("unlock")' if unlock is not None else "null"
    lines += [
        "[resource]",
        'script = ExtResource("1_ilay")',
        f'layer_id = "{layer_id}"',
        f'display_name = "{display_name}"',
        f"base_value = {int(base_value)}",
        f"unlock_action = {unlock_ref}",
        "",
    ]
    return "\n".join(lines)


def _build_item_tres(
    item_id: str,
    item_uid: str,
    category_id: str | None,
    category_uid: str | None,
    rarity: int,
    layers: list[dict],
    item_data_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="ItemData" format=3 uid="{item_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{item_data_script_uid}" '
        f'path="res://data/definitions/item_data.gd" id="1_jyqit"]',
    ]

    if category_uid and category_id:
        lines.append(
            f'[ext_resource type="Resource" uid="{category_uid}" '
            f'path="res://data/tres/categories/{category_id}.tres" id="2_cat"]'
        )

    for i, layer in enumerate(layers):
        tag = f"{3 + i}_layer"
        lines.append(
            f'[ext_resource type="Resource" uid="{layer["layer_uid"]}" '
            f'path="res://data/tres/identity_layers/{layer["layer_id"]}.tres" id="{tag}"]'
        )

    cat_ref = 'ExtResource("2_cat")' if (category_uid and category_id) else "null"
    layer_refs = ", ".join(f'ExtResource("{3 + i}_layer")' for i in range(len(layers)))

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_jyqit")',
        f'item_id = "{item_id}"',
        f"category_data = {cat_ref}",
        f"identity_layers = [{layer_refs}]",
        f"rarity = {int(rarity)}",
        "",
    ]
    return "\n".join(lines)


def _build_car_tres(
    car_id: str,
    car_uid: str,
    display_name: str,
    grid_columns: int,
    grid_rows: int,
    max_weight: float,
    stamina_cap: int,
    fuel_cost_per_day: int,
    extra_slot_count: int,
    price: int,
    icon_path: str,
    car_data_script_uid: str,
) -> str:
    has_icon = bool(icon_path)
    load_steps = 3 if has_icon else 2

    lines = [
        f'[gd_resource type="Resource" script_class="CarData" '
        f'load_steps={load_steps} format=3 uid="{car_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{car_data_script_uid}" '
        f'path="res://data/definitions/car_data.gd" id="1_cardef"]',
    ]

    if has_icon:
        lines.append(f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]')

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_cardef")',
        f'car_id = "{car_id}"',
        f'display_name = "{display_name}"',
        f"grid_columns = {int(grid_columns)}",
        f"grid_rows = {int(grid_rows)}",
        f"max_weight = {float(max_weight)}",
        f"stamina_cap = {int(stamina_cap)}",
        f"fuel_cost_per_day = {int(fuel_cost_per_day)}",
        f"extra_slot_count = {int(extra_slot_count)}",
        f"price = {int(price)}",
    ]

    if has_icon:
        lines.append('icon = ExtResource("2_icon")')

    lines.append("")
    return "\n".join(lines)


# ── Export phases ─────────────────────────────────────────────────────────────


def _write(out_path: Path, content: str, dry_run: bool, label: str) -> None:
    if dry_run:
        print(f"  [dry] would write {out_path}")
    else:
        out_path.write_text(content, encoding="utf-8")
        print(f"  {label} → {out_path.name}")


def export_skills(
    skills: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    skill_data_script_uid: str,
    skill_level_data_script_uid: str,
) -> None:
    for skill in skills:
        sid = skill["skill_id"]
        out = out_dir / f"{sid}.tres"
        uid = _deterministic_uid("skill", sid)
        uid_cache[sid] = uid
        content = _build_skill_tres(
            sid,
            uid,
            skill["display_name"],
            skill["levels"],
            skill_data_script_uid,
            skill_level_data_script_uid,
        )
        _write(out, content, dry_run, f"skill ({len(skill['levels'])} levels)")


def export_super_categories(
    super_categories: list,
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    super_category_data_script_uid: str,
) -> None:
    for entry in super_categories:
        display_name = str(entry)
        super_category_id = display_name.lower().replace(" ", "_")
        out = out_dir / f"{super_category_id}.tres"
        uid = _deterministic_uid("super_category", super_category_id)
        uid_cache[super_category_id] = uid
        content = _build_super_category_tres(
            super_category_id,
            uid,
            display_name,
            super_category_data_script_uid,
        )
        _write(out, content, dry_run, "super_category")


def export_categories(
    categories: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    category_data_script_uid: str,
) -> None:
    for cat in categories:
        cat_id = cat["category_id"]
        super_cat_id = str(cat["super_category"]).lower().replace(" ", "_")
        super_cat_uid = uid_cache.get(super_cat_id, "")

        out = out_dir / f"{cat_id}.tres"
        uid = _deterministic_uid("category", cat_id)
        uid_cache[cat_id] = uid

        content = _build_category_tres(
            cat_id,
            uid,
            super_cat_id,
            super_cat_uid,
            cat["display_name"],
            float(cat.get("weight", 0.0)),
            str(cat.get("shape_id", "s1x1")),
            category_data_script_uid,
        )
        _write(out, content, dry_run, "category")


def export_identity_layers(
    layers: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    identity_layer_script_uid: str,
    layer_unlock_script_uid: str,
) -> None:
    for layer in layers:
        layer_id = layer["layer_id"]
        out = out_dir / f"{layer_id}.tres"
        uid = _deterministic_uid("identity_layer", layer_id)
        uid_cache[layer_id] = uid

        content = _build_layer_tres(
            layer_id,
            uid,
            layer["display_name"],
            int(layer["base_value"]),
            layer.get("unlock_action"),
            uid_cache,
            identity_layer_script_uid,
            layer_unlock_script_uid,
        )
        _write(out, content, dry_run, "layer")


def export_items(
    items: list[dict],
    identity_layers: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    item_data_script_uid: str,
) -> None:
    layers_by_id = {l["layer_id"]: l for l in identity_layers}

    for item in items:
        item_id = item["item_id"]
        out = out_dir / f"{item_id}.tres"
        uid = _deterministic_uid("item", item_id)
        uid_cache[item_id] = uid

        cat_id = item.get("category_id")
        cat_uid = uid_cache.get(cat_id) if cat_id else None

        layer_refs: list[dict] = []
        for lid in item.get("layer_ids", []):
            src = layers_by_id.get(lid, {})
            layer_refs.append(
                {
                    "layer_id": lid,
                    "layer_uid": uid_cache.get(lid, ""),
                    "display_name": src.get("display_name", ""),
                    "base_value": src.get("base_value", 0),
                }
            )

        content = _build_item_tres(
            item_id,
            uid,
            cat_id,
            cat_uid,
            int(item.get("rarity", 0)),
            layer_refs,
            item_data_script_uid,
        )
        _write(out, content, dry_run, f"item ({len(layer_refs)} layers)")


def export_cars(
    cars: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
    car_data_script_uid: str,
) -> None:
    for car in cars:
        car_id = car["car_id"]
        out = out_dir / f"{car_id}.tres"
        uid = _deterministic_uid("car", car_id)
        uid_cache[car_id] = uid

        content = _build_car_tres(
            car_id,
            uid,
            car["display_name"],
            int(car["grid_columns"]),
            int(car["grid_rows"]),
            float(car["max_weight"]),
            int(car["stamina_cap"]),
            int(car.get("fuel_cost_per_day", 0)),
            int(car.get("extra_slot_count", 0)),
            int(car.get("price", 0)),
            str(car.get("icon", "")),
            car_data_script_uid,
        )
        _write(out, content, dry_run, "car")


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Write .tres asset files directly from YAML source files."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--yaml-dir",
        default=None,
        help="Directory containing YAML files (default: <godot-root>/data/yaml)",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = Path(args.godot_root)
    yaml_dir = Path(args.yaml_dir) if args.yaml_dir else root / "data" / "yaml"
    tres_root = root / "data" / "tres"
    skills_dir = tres_root / "skills"
    super_categories_dir = tres_root / "super_categories"
    categories_dir = tres_root / "categories"
    layers_dir = tres_root / "identity_layers"
    items_dir = tres_root / "items"
    cars_dir = tres_root / "cars"

    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    # ── Resolve script UIDs from .gd.uid sidecar files ───────────────────────
    script_uids: dict[str, str] = {
        "item_data": _read_script_uid(root, _ITEM_DATA_SCRIPT_PATH),
        "identity_layer": _read_script_uid(root, _IDENTITY_LAYER_SCRIPT_PATH),
        "layer_unlock_action": _read_script_uid(root, _LAYER_UNLOCK_SCRIPT_PATH),
        "category_data": _read_script_uid(root, _CATEGORY_DATA_SCRIPT_PATH),
        "super_category_data": _read_script_uid(root, _SUPER_CATEGORY_DATA_SCRIPT_PATH),
        "skill_data": _read_script_uid(root, _SKILL_DATA_SCRIPT_PATH),
        "skill_level_data": _read_script_uid(root, _SKILL_LEVEL_DATA_SCRIPT_PATH),
        "car_data": _read_script_uid(root, _CAR_DATA_SCRIPT_PATH),
    }

    yaml_files = sorted(yaml_dir.glob("*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    # ── Merge all files into one dataset ──────────────────────────────────────
    merged: dict[str, list] = {
        "skills": [],
        "super_categories": [],
        "categories": [],
        "identity_layers": [],
        "items": [],
        "cars": [],
    }

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    # ── Validate ──────────────────────────────────────────────────────────────
    print("Validating...")
    errors = validate(merged)
    if errors:
        print(f"  {len(errors)} error(s) found — aborting:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")

    # ── Create output directories ─────────────────────────────────────────────
    if not args.dry_run:
        for d in (
            skills_dir,
            super_categories_dir,
            categories_dir,
            layers_dir,
            items_dir,
            cars_dir,
        ):
            d.mkdir(parents=True, exist_ok=True)

    # ── Export in dependency order ────────────────────────────────────────────
    uid_cache: dict[str, str] = {}

    if merged["skills"]:
        print(f"Exporting skills ({len(merged['skills'])})...")
        export_skills(
            merged["skills"],
            skills_dir,
            uid_cache,
            args.dry_run,
            script_uids["skill_data"],
            script_uids["skill_level_data"],
        )

    print(f"Exporting super_categories ({len(merged['super_categories'])})...")
    export_super_categories(
        merged["super_categories"],
        super_categories_dir,
        uid_cache,
        args.dry_run,
        script_uids["super_category_data"],
    )

    print(f"Exporting categories ({len(merged['categories'])})...")
    export_categories(
        merged["categories"],
        categories_dir,
        uid_cache,
        args.dry_run,
        script_uids["category_data"],
    )

    print(f"Exporting identity_layers ({len(merged['identity_layers'])})...")
    export_identity_layers(
        merged["identity_layers"],
        layers_dir,
        uid_cache,
        args.dry_run,
        script_uids["identity_layer"],
        script_uids["layer_unlock_action"],
    )

    print(f"Exporting items ({len(merged['items'])})...")
    export_items(
        merged["items"],
        merged["identity_layers"],
        items_dir,
        uid_cache,
        args.dry_run,
        script_uids["item_data"],
    )

    print(f"Exporting cars ({len(merged['cars'])})...")
    export_cars(
        merged["cars"],
        cars_dir,
        uid_cache,
        args.dry_run,
        script_uids["car_data"],
    )

    total = (
        len(merged["skills"])
        + len(merged["super_categories"])
        + len(merged["categories"])
        + len(merged["identity_layers"])
        + len(merged["items"])
        + len(merged["cars"])
    )
    tag = "[dry run] " if args.dry_run else ""
    print(f"\n{tag}Done — {total} records processed.")


if __name__ == "__main__":
    main()
