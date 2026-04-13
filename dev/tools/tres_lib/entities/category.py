"""EntitySpec for categories."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import (
    header_uid,
    field as tres_field,
    ext_resources,
)

_VALID_SHAPE_IDS: frozenset[str] = frozenset({
    "s1x1", "s1x2", "s1x3", "s1x4",
    "s2x2", "s2x3", "s2x4",
    "sL11", "sL12", "sT3",
})


@dataclass
class CategorySpec:
    yaml_key: str = "categories"
    tres_subdir: str = "categories"
    uid_prefix: str = "category"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "category_data": "res://data/definitions/category_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["category_id"]

    def build_label(self, entry: dict) -> str:
        return "category"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        cat_id = entry["category_id"]
        super_cat_id = str(entry["super_category"]).lower().replace(" ", "_")
        super_cat_uid = ctx.uid_cache.get(super_cat_id, "")

        uid = deterministic_uid(self.uid_prefix, cat_id)
        ctx.uid_cache[cat_id] = uid

        w = TresWriter("Resource", "CategoryData", uid)
        w.add_ext_resource(
            "1_catdef",
            "Script",
            "res://data/definitions/category_data.gd",
            ctx.script_uids["category_data"],
        )
        w.add_ext_resource(
            "2_super",
            "Resource",
            f"res://data/tres/super_categories/{super_cat_id}.tres",
            super_cat_uid,
        )
        w.add_field('script = ExtResource("1_catdef")')
        w.add_field_str("category_id", cat_id)
        w.add_field('super_category = ExtResource("2_super")')
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_float("weight", float(entry.get("weight", 0.0)))
        w.add_field_str("shape_id", str(entry.get("shape_id", "s1x1")))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        cat_id = tres_field(text, "category_id") or ""
        if uid:
            ctx.uid_to_id[uid] = cat_id

        display_name = tres_field(text, "display_name") or cat_id
        weight = float(tres_field(text, "weight") or 0.0)
        shape_id = tres_field(text, "shape_id") or "s1x1"

        ext_res = ext_resources(text)
        super_cat_display = ""
        cat_m = re.search(r'super_category\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            sc_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            sc_id = ctx.uid_to_id.get(sc_uid, "")
            super_cat_display = ctx.super_cat_display_by_id.get(
                sc_id, sc_id.replace("_", " ").title()
            )

        return {
            "category_id": cat_id,
            "super_category": super_cat_display,
            "display_name": display_name,
            "weight": weight,
            "shape_id": shape_id,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        for cat in entries:
            cid = cat.get("category_id", "?")
            shape_id = cat.get("shape_id")
            if shape_id is None:
                errors.append(f"category '{cid}': missing shape_id")
            elif shape_id not in _VALID_SHAPE_IDS:
                errors.append(
                    f"category '{cid}': unknown shape_id '{shape_id}'"
                    f" — valid: {sorted(_VALID_SHAPE_IDS)}"
                )
        return errors


SPEC = CategorySpec()
