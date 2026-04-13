"""
tres_to_yaml.py
Reconstruct YAML source data from .tres asset files under data/tres/.

Walks: data/tres/skills/, data/tres/super_categories/, data/tres/categories/,
       data/tres/identity_layers/, data/tres/items/

Usage:
    python tres_to_yaml.py --godot-root /path/to/godot/project
    python tres_to_yaml.py --godot-root /path/to/godot/project --output data.yaml
"""

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── .tres parsing helpers ─────────────────────────────────────────────────────


def _header_uid(text: str) -> str | None:
    m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
    return m.group(1) if m else None


def _ext_resources(text: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for m in re.finditer(r"\[ext_resource([^\]]+)\]", text):
        a = m.group(1)

        def _a(k: str) -> str:
            r = re.search(rf'(?<![a-z]){k}="([^"]+)"', a)
            return r.group(1) if r else ""

        tag = _a("id")
        if tag:
            out[tag] = {"uid": _a("uid"), "path": _a("path"), "type": _a("type")}
    return out


def _field(text: str, key: str) -> str | None:
    """Read a scalar field from a .tres [resource] block.

    Captures everything to end-of-line and strips surrounding quotes, so
    string literals like `display_name = "Foo"` and expression values like
    `unlock_action = SubResource("unlock")` are both returned verbatim
    (without the outer quotes for pure strings).
    """
    m = re.search(rf"^{re.escape(key)}\s*=\s*(.+?)\s*$", text, re.MULTILINE)
    if not m:
        return None
    val = m.group(1).strip()
    if len(val) >= 2 and val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
    return val


def _sub_resources(text: str) -> dict[str, dict[str, str]]:
    subs: dict[str, dict[str, str]] = {}
    for bm in re.finditer(
        r'\[sub_resource[^\]]*id="([^"]+)"\](.*?)(?=\n\[|\Z)', text, re.DOTALL
    ):
        fields: dict[str, str] = {}
        for line in bm.group(2).splitlines():
            m = re.match(r"(\w+)\s*=\s*(.+)", line.strip())
            if m:
                fields[m.group(1)] = m.group(2).strip().strip('"')
        subs[bm.group(1)] = fields
    return subs


# ── Godot Dictionary literal parsing ──────────────────────────────────────────


def _split_dict_pairs(body: str) -> list[str]:
    """Split key:value pairs on top-level commas, respecting nested {}/[]."""
    pairs: list[str] = []
    depth = 0
    buf: list[str] = []
    for ch in body:
        if ch in "{[":
            depth += 1
        elif ch in "}]":
            depth -= 1
        if ch == "," and depth == 0:
            pairs.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        pairs.append("".join(buf))
    return pairs


def _parse_godot_dict(text: str) -> dict:
    """Parse a Godot Dictionary literal like { "foo": 1, "bar": 2 }."""
    text = (text or "").strip()
    if not (text.startswith("{") and text.endswith("}")):
        return {}
    body = text[1:-1].strip()
    if not body:
        return {}
    out: dict = {}
    for pair in _split_dict_pairs(body):
        km = re.match(r'^\s*"([^"]*)"\s*:\s*(.+?)\s*$', pair)
        if not km:
            continue
        key = km.group(1)
        val_s = km.group(2).strip()
        try:
            out[key] = int(val_s)
        except ValueError:
            try:
                out[key] = float(val_s)
            except ValueError:
                out[key] = val_s.strip('"')
    return out


# ── Parsers per entity type ───────────────────────────────────────────────────


def parse_skills(
    skills_dir: Path,
    uid_to_id: dict[str, str],
) -> list[dict]:
    skills: list[dict] = []
    if not skills_dir.is_dir():
        return skills

    for f in sorted(skills_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        skill_id = _field(text, "skill_id") or f.stem
        if uid:
            uid_to_id[uid] = skill_id

        display_name = _field(text, "display_name") or skill_id
        subs = _sub_resources(text)

        level_ids = [sid for sid in subs if sid.startswith("lvl_")]
        level_ids.sort(
            key=lambda s: int(s.split("_", 1)[1]) if s.split("_", 1)[1].isdigit() else 0
        )

        levels: list[dict] = []
        for lid in level_ids:
            fields = subs[lid]
            levels.append(
                {
                    "cash_cost": int(fields.get("cash_cost", "0")),
                    "required_mastery_rank": int(
                        fields.get("required_mastery_rank", "0")
                    ),
                    "required_super_category_ranks": _parse_godot_dict(
                        fields.get("required_super_category_ranks", "{}")
                    ),
                }
            )

        skills.append(
            {
                "skill_id": skill_id,
                "display_name": display_name,
                "levels": levels,
            }
        )
    return skills


def parse_super_categories(
    super_categories_dir: Path,
    uid_to_id: dict[str, str],
    display_by_id: dict[str, str],
) -> list[str]:
    out: list[str] = []
    if not super_categories_dir.is_dir():
        return out

    for f in sorted(super_categories_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        super_cat_id = _field(text, "super_category_id") or f.stem
        display_name = _field(text, "display_name") or super_cat_id
        if uid:
            uid_to_id[uid] = super_cat_id
        display_by_id[super_cat_id] = display_name
        out.append(display_name)
    return out


def parse_categories(
    categories_dir: Path,
    uid_to_id: dict[str, str],
    super_cat_display_by_id: dict[str, str],
) -> list[dict]:
    out: list[dict] = []
    if not categories_dir.is_dir():
        return out

    for f in sorted(categories_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        cat_id = _field(text, "category_id") or f.stem
        if uid:
            uid_to_id[uid] = cat_id

        display_name = _field(text, "display_name") or cat_id
        weight = float(_field(text, "weight") or 0.0)
        shape_id = _field(text, "shape_id") or "s1x1"

        ext_res = _ext_resources(text)
        super_cat_display = ""
        cat_m = re.search(r'super_category\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            sc_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            sc_id = uid_to_id.get(sc_uid, "")
            super_cat_display = super_cat_display_by_id.get(
                sc_id, sc_id.replace("_", " ").title()
            )

        out.append(
            {
                "category_id": cat_id,
                "super_category": super_cat_display,
                "display_name": display_name,
                "weight": weight,
                "shape_id": shape_id,
            }
        )
    return out


def parse_identity_layers(
    layers_dir: Path,
    uid_to_id: dict[str, str],
) -> list[dict]:
    out: list[dict] = []
    if not layers_dir.is_dir():
        return out

    for f in sorted(layers_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        layer_id = _field(text, "layer_id") or f.stem
        if uid:
            uid_to_id[uid] = layer_id

        display_name = _field(text, "display_name") or layer_id
        base_value = int(_field(text, "base_value") or 0)

        subs = _sub_resources(text)
        ext_res = _ext_resources(text)

        unlock: dict | None = None
        unlock_raw = _field(text, "unlock_action")
        if unlock_raw and unlock_raw != "null":
            m = re.match(r'SubResource\("([^"]+)"\)', unlock_raw)
            if m:
                fields = subs.get(m.group(1), {})
                ctx = int(fields.get("context", "1"))
                unlock = {"context": ctx}

                unlock_days = int(fields.get("unlock_days", "0"))
                if ctx == 1 or unlock_days:
                    unlock["unlock_days"] = unlock_days

                skill_raw = fields.get("required_skill", "null")
                sm = re.match(r'ExtResource\("([^"]+)"\)', skill_raw)
                if sm:
                    skill_uid = ext_res.get(sm.group(1), {}).get("uid", "")
                    skill_id = uid_to_id.get(skill_uid, "")
                    if skill_id:
                        unlock["required_skill"] = skill_id
                        required_level = int(fields.get("required_level", "0"))
                        if required_level:
                            unlock["required_level"] = required_level

                required_condition = float(fields.get("required_condition", "0.0"))
                if required_condition:
                    unlock["required_condition"] = required_condition

                required_category_rank = int(
                    fields.get("required_category_rank", "0")
                )
                if required_category_rank:
                    unlock["required_category_rank"] = required_category_rank

                required_perk_id = fields.get("required_perk_id", "").strip('"')
                if required_perk_id:
                    unlock["required_perk_id"] = required_perk_id

        out.append(
            {
                "layer_id": layer_id,
                "display_name": display_name,
                "base_value": base_value,
                "unlock_action": unlock,
            }
        )
    return out


def parse_items(
    items_dir: Path,
    uid_to_id: dict[str, str],
) -> list[dict]:
    out: list[dict] = []
    if not items_dir.is_dir():
        return out

    for f in sorted(items_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        item_id = _field(text, "item_id") or f.stem
        if uid:
            uid_to_id[uid] = item_id

        rarity = int(_field(text, "rarity") or 0)

        ext_res = _ext_resources(text)
        category_id = ""
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_id = uid_to_id.get(cat_uid, "")

        layer_ids: list[str] = []
        il_m = re.search(r"identity_layers\s*=\s*\[([^\]]*)\]", text)
        if il_m:
            for tag_m in re.finditer(r'ExtResource\("([^"]+)"\)', il_m.group(1)):
                layer_uid = ext_res.get(tag_m.group(1), {}).get("uid", "")
                lid = uid_to_id.get(layer_uid, "")
                if lid:
                    layer_ids.append(lid)

        out.append(
            {
                "item_id": item_id,
                "category_id": category_id,
                "rarity": rarity,
                "layer_ids": layer_ids,
            }
        )
    return out


def parse_lots(
    lots_dir: Path,
    uid_to_id: dict[str, str],
) -> list[dict]:
    out: list[dict] = []
    if not lots_dir.is_dir():
        return out

    _FLOAT_FIELDS = [
        "aggressive_factor_min",
        "aggressive_factor_max",
        "aggressive_lerp_min",
        "aggressive_lerp_max",
        "npc_layer_sight_chance",
        "opening_bid_factor",
        "veiled_chance",
        "price_floor_factor",
        "price_ceiling_factor",
        "price_variance_min",
        "price_variance_max",
    ]
    _INT_FIELDS = [
        "item_count_min",
        "item_count_max",
        "action_quota",
    ]
    _DICT_FIELDS = [
        "rarity_weights",
        "super_category_weights",
        "category_weights",
    ]

    for f in sorted(lots_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        lot_id = _field(text, "lot_id") or f.stem
        if uid:
            uid_to_id[uid] = lot_id

        lot: dict = {"lot_id": lot_id}
        for key in _FLOAT_FIELDS:
            val = _field(text, key)
            if val is not None:
                lot[key] = float(val)
        for key in _INT_FIELDS:
            val = _field(text, key)
            if val is not None:
                lot[key] = int(val)
        for key in _DICT_FIELDS:
            val = _field(text, key)
            if val is not None:
                lot[key] = _parse_godot_dict(val)

        out.append(lot)
    return out


def parse_locations(
    locations_dir: Path,
    uid_to_id: dict[str, str],
) -> list[dict]:
    out: list[dict] = []
    if not locations_dir.is_dir():
        return out

    for f in sorted(locations_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        location_id = _field(text, "location_id") or f.stem
        if uid:
            uid_to_id[uid] = location_id

        display_name = _field(text, "display_name") or location_id
        description = _field(text, "description") or ""
        entry_fee = int(_field(text, "entry_fee") or 0)
        travel_days = int(_field(text, "travel_days") or 1)
        lot_number = int(_field(text, "lot_number") or 3)

        ext_res = _ext_resources(text)

        lot_ids: list[str] = []
        lp_m = re.search(r"lot_pool\s*=\s*\[([^\]]*)\]", text)
        if lp_m:
            for tag_m in re.finditer(r'ExtResource\("([^"]+)"\)', lp_m.group(1)):
                lot_uid = ext_res.get(tag_m.group(1), {}).get("uid", "")
                lid = uid_to_id.get(lot_uid, "")
                if lid:
                    lot_ids.append(lid)

        out.append(
            {
                "location_id": location_id,
                "display_name": display_name,
                "description": description,
                "entry_fee": entry_fee,
                "travel_days": travel_days,
                "lot_number": lot_number,
                "lot_pool": lot_ids,
            }
        )
    return out


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Reconstruct YAML source data from .tres asset files."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--output",
        default=None,
        help="Write YAML here (default: stdout)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    tres_root = root / "data" / "tres"

    uid_to_id: dict[str, str] = {}
    super_cat_display_by_id: dict[str, str] = {}

    # Parse in dependency order so that reverse references can be resolved.
    skills = parse_skills(tres_root / "skills", uid_to_id)
    super_categories = parse_super_categories(
        tres_root / "super_categories", uid_to_id, super_cat_display_by_id
    )
    categories = parse_categories(
        tres_root / "categories", uid_to_id, super_cat_display_by_id
    )
    identity_layers = parse_identity_layers(
        tres_root / "identity_layers", uid_to_id
    )
    items = parse_items(tres_root / "items", uid_to_id)
    lots = parse_lots(tres_root / "lots", uid_to_id)
    locations = parse_locations(tres_root / "locations", uid_to_id)

    data: dict = {}
    if skills:
        data["skills"] = skills
    if super_categories:
        data["super_categories"] = super_categories
    if categories:
        data["categories"] = categories
    if identity_layers:
        data["identity_layers"] = identity_layers
    if items:
        data["items"] = items
    if lots:
        data["lots"] = lots
    if locations:
        data["locations"] = locations

    yaml_text = yaml.dump(
        data,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(yaml_text, encoding="utf-8")
        print(f"Wrote {out_path}")
    else:
        sys.stdout.write(yaml_text)


if __name__ == "__main__":
    main()
