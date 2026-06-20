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
        super_cat_id = entry["super_category"]
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
        w.add_field_str("display_name_key", entry.get("display_name_key", ""))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        cat_id = tres_field(text, "category_id") or ""
        if uid:
            ctx.uid_to_id[uid] = cat_id

        display_name_key = tres_field(text, "display_name_key") or cat_id

        ext_res = ext_resources(text)
        super_cat_id = ""
        cat_m = re.search(r'super_category\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            sc_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            super_cat_id = ctx.uid_to_id.get(sc_uid, "")

        return {
            "category_id": cat_id,
            "super_category": super_cat_id,
            "display_name_key": display_name_key,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_super_cat_ids: set[str] = set()
        for sc in all_data.get("super_categories", []):
            if isinstance(sc, dict):
                known_super_cat_ids.add(sc["super_category_id"])
            else:
                known_super_cat_ids.add(str(sc).lower().replace(" ", "_"))

        for cat in entries:
            cid = cat.get("category_id", "?")
            sc_ref = cat.get("super_category", "")
            if known_super_cat_ids and sc_ref not in known_super_cat_ids:
                errors.append(
                    f"category '{cid}': super_category '{sc_ref}' not found "
                    f"in known super_category ids: {sorted(known_super_cat_ids)}"
                )

        return errors


SPEC = CategorySpec()
