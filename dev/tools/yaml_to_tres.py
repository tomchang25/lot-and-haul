"""
yaml_to_tres.py
Write SkillData, SuperCategoryData, CategoryData, IdentityLayer, and ItemData
.tres files directly from YAML source files, without an intermediate database.

Existing Godot UIDs are preserved by reading the header line of each existing
.tres file on disk. Entities that have no .tres yet get a freshly generated
uid://... identifier.

Usage:
    python yaml_to_tres.py --godot-root /path/to/godot/project
    python yaml_to_tres.py --godot-root /path/to/godot/project --dry-run
    python yaml_to_tres.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import random
import re
import string
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── UID helpers ───────────────────────────────────────────────────────────────

_UID_CHARS = string.ascii_lowercase + string.digits


def _new_uid() -> str:
    return "uid://" + "".join(random.choices(_UID_CHARS, k=12))


def _read_existing_uid(tres_path: Path) -> str | None:
    """Extract uid://... from the first line of an existing .tres file."""
    if not tres_path.exists():
        return None
    with tres_path.open("r", encoding="utf-8") as f:
        first_line = f.readline()
    m = re.search(r'uid="(uid://[a-z0-9]+)"', first_line)
    return m.group(1) if m else None


# ── Script UID constants ──────────────────────────────────────────────────────

_ITEM_DATA_SCRIPT_UID = "uid://bhqs42afjqbgi"
_IDENTITY_LAYER_SCRIPT_UID = "uid://btknl1cvjqdvh"
_LAYER_UNLOCK_SCRIPT_UID = "uid://c23t4blqmaaj4"
_CATEGORY_DATA_SCRIPT_UID = "uid://c7fq6wupmgchg"
_SUPER_CATEGORY_DATA_SCRIPT_UID = "uid://d4gdoi2l561vy"


# ── Skill script UID discovery ────────────────────────────────────────────────


def _discover_skill_script_uids(
    skills_dir: Path,
) -> tuple[str | None, str | None]:
    """Scan existing skill .tres files to find SkillData and SkillLevelData
    script UIDs. Returns (skill_data_uid, skill_level_data_uid)."""
    skill_data_uid: str | None = None
    skill_level_data_uid: str | None = None

    if not skills_dir.is_dir():
        return None, None

    for f in skills_dir.glob("*.tres"):
        text = f.read_text(encoding="utf-8")
        for m in re.finditer(
            r'\[ext_resource[^\]]*uid="([^"]+)"[^\]]*path="([^"]+)"[^\]]*\]',
            text,
        ):
            uid, path = m.group(1), m.group(2)
            if path.endswith("skill_data.gd"):
                skill_data_uid = uid
            elif path.endswith("skill_level_data.gd"):
                skill_level_data_uid = uid

        if skill_data_uid and skill_level_data_uid:
            break

    return skill_data_uid, skill_level_data_uid


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
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="SuperCategoryData" format=3 uid="{super_category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_SUPER_CATEGORY_DATA_SCRIPT_UID}" '
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
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="CategoryData" format=3 uid="{category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_CATEGORY_DATA_SCRIPT_UID}" '
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
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="IdentityLayer" format=3 uid="{layer_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_IDENTITY_LAYER_SCRIPT_UID}" '
        f'path="res://data/definitions/identity_layer.gd" id="1_ilay"]',
    ]

    if unlock is not None:
        lines.append(
            f'[ext_resource type="Script" uid="{_LAYER_UNLOCK_SCRIPT_UID}" '
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
            lines.append(
                f'required_condition = {float(unlock["required_condition"])}'
            )
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
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="ItemData" format=3 uid="{item_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_ITEM_DATA_SCRIPT_UID}" '
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


# ── Validation ────────────────────────────────────────────────────────────────


_VALID_SHAPE_IDS: frozenset[str] = frozenset(
    {
        "s1x1",
        "s1x2",
        "s1x3",
        "s2x2",
        "s2x3",
        "s2x4",
        "sL11",
        "sL12",
        "sT3",
    }
)


def _validate(data: dict) -> list[str]:
    """Return a list of error strings. Empty list means OK."""
    errors: list[str] = []

    # ── Skills ────────────────────────────────────────────────────────────────
    skills = data.get("skills", [])
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

    known_skill_ids = set(seen_skill_ids)

    # ── Categories ────────────────────────────────────────────────────────────
    known_cat_ids: set[str] = {c["category_id"] for c in data.get("categories", [])}

    for cat in data.get("categories", []):
        cid = cat.get("category_id", "?")
        shape_id = cat.get("shape_id")
        if shape_id is None:
            errors.append(f"category '{cid}': missing shape_id")
        elif shape_id not in _VALID_SHAPE_IDS:
            errors.append(
                f"category '{cid}': unknown shape_id '{shape_id}'"
                f" — valid: {sorted(_VALID_SHAPE_IDS)}"
            )

    # ── Identity layers ───────────────────────────────────────────────────────
    known_layer_ids: set[str] = {
        l["layer_id"] for l in data.get("identity_layers", [])
    }

    for layer in data.get("identity_layers", []):
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

    # ── Items ─────────────────────────────────────────────────────────────────
    for item in data.get("items", []):
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
                (l for l in data["identity_layers"] if l["layer_id"] == layer_ids[0]),
                None,
            )
            if first:
                ctx0 = (first.get("unlock_action") or {}).get("context")
                if ctx0 != 0:
                    errors.append(
                        f"item '{iid}': layer[0] '{layer_ids[0]}' must have context=0 (AUTO)"
                    )

            last = next(
                (l for l in data["identity_layers"] if l["layer_id"] == layer_ids[-1]),
                None,
            )
            if last and last.get("unlock_action") is not None:
                errors.append(
                    f"item '{iid}': final layer '{layer_ids[-1]}' must have unlock_action: null"
                )

    return errors


# ── Export phases ─────────────────────────────────────────────────────────────


def _resolve_or_new_uid(out_path: Path) -> str:
    """Read UID from an existing .tres or mint a new one."""
    return _read_existing_uid(out_path) or _new_uid()


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
        uid = _resolve_or_new_uid(out)
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
) -> None:
    for entry in super_categories:
        display_name = str(entry)
        super_category_id = display_name.lower().replace(" ", "_")
        out = out_dir / f"{super_category_id}.tres"
        uid = _resolve_or_new_uid(out)
        uid_cache[super_category_id] = uid
        content = _build_super_category_tres(super_category_id, uid, display_name)
        _write(out, content, dry_run, "super_category")


def export_categories(
    categories: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
) -> None:
    for cat in categories:
        cat_id = cat["category_id"]
        super_cat_id = str(cat["super_category"]).lower().replace(" ", "_")
        super_cat_uid = uid_cache.get(super_cat_id, "")

        out = out_dir / f"{cat_id}.tres"
        uid = _resolve_or_new_uid(out)
        uid_cache[cat_id] = uid

        content = _build_category_tres(
            cat_id,
            uid,
            super_cat_id,
            super_cat_uid,
            cat["display_name"],
            float(cat.get("weight", 0.0)),
            str(cat.get("shape_id", "s1x1")),
        )
        _write(out, content, dry_run, "category")


def export_identity_layers(
    layers: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
) -> None:
    for layer in layers:
        layer_id = layer["layer_id"]
        out = out_dir / f"{layer_id}.tres"
        uid = _resolve_or_new_uid(out)
        uid_cache[layer_id] = uid

        content = _build_layer_tres(
            layer_id,
            uid,
            layer["display_name"],
            int(layer["base_value"]),
            layer.get("unlock_action"),
            uid_cache,
        )
        _write(out, content, dry_run, "layer")


def export_items(
    items: list[dict],
    identity_layers: list[dict],
    out_dir: Path,
    uid_cache: dict[str, str],
    dry_run: bool,
) -> None:
    layers_by_id = {l["layer_id"]: l for l in identity_layers}

    for item in items:
        item_id = item["item_id"]
        out = out_dir / f"{item_id}.tres"
        uid = _resolve_or_new_uid(out)
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
        )
        _write(out, content, dry_run, f"item ({len(layer_refs)} layers)")


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
    parser.add_argument(
        "--skill-data-uid",
        default=None,
        help="Script UID for skill_data.gd (auto-discovered from existing .tres if omitted)",
    )
    parser.add_argument(
        "--skill-level-data-uid",
        default=None,
        help="Script UID for skill_level_data.gd (auto-discovered from existing .tres if omitted)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    yaml_dir = Path(args.yaml_dir) if args.yaml_dir else root / "data" / "yaml"
    tres_root = root / "data" / "tres"
    skills_dir = tres_root / "skills"
    super_categories_dir = tres_root / "super_categories"
    categories_dir = tres_root / "categories"
    layers_dir = tres_root / "identity_layers"
    items_dir = tres_root / "items"

    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

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
    errors = _validate(merged)
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
        ):
            d.mkdir(parents=True, exist_ok=True)

    # ── Resolve skill script UIDs ─────────────────────────────────────────────
    discovered_sd, discovered_sld = _discover_skill_script_uids(skills_dir)
    skill_data_uid = args.skill_data_uid or discovered_sd
    skill_level_data_uid = args.skill_level_data_uid or discovered_sld

    if merged["skills"] and not (skill_data_uid and skill_level_data_uid):
        msg = "Cannot determine skill script UIDs.\n"
        if not skill_data_uid:
            msg += "  Missing: skill_data.gd UID (pass --skill-data-uid)\n"
        if not skill_level_data_uid:
            msg += "  Missing: skill_level_data.gd UID (pass --skill-level-data-uid)\n"
        msg += (
            "\nTip: create one SkillData .tres in the Godot editor first, then re-run.\n"
            "The script will then auto-discover script UIDs from existing files."
        )
        sys.exit(msg)

    # ── Export in dependency order ────────────────────────────────────────────
    uid_cache: dict[str, str] = {}

    if merged["skills"]:
        print(f"Exporting skills ({len(merged['skills'])})...")
        export_skills(
            merged["skills"],
            skills_dir,
            uid_cache,
            args.dry_run,
            skill_data_uid or "",
            skill_level_data_uid or "",
        )

    print(f"Exporting super_categories ({len(merged['super_categories'])})...")
    export_super_categories(
        merged["super_categories"], super_categories_dir, uid_cache, args.dry_run
    )

    print(f"Exporting categories ({len(merged['categories'])})...")
    export_categories(merged["categories"], categories_dir, uid_cache, args.dry_run)

    print(f"Exporting identity_layers ({len(merged['identity_layers'])})...")
    export_identity_layers(
        merged["identity_layers"], layers_dir, uid_cache, args.dry_run
    )

    print(f"Exporting items ({len(merged['items'])})...")
    export_items(
        merged["items"],
        merged["identity_layers"],
        items_dir,
        uid_cache,
        args.dry_run,
    )

    total = (
        len(merged["skills"])
        + len(merged["super_categories"])
        + len(merged["categories"])
        + len(merged["identity_layers"])
        + len(merged["items"])
    )
    tag = "[dry run] " if args.dry_run else ""
    print(f"\n{tag}Done — {total} records processed.")


if __name__ == "__main__":
    main()
