"""EntitySpec for commodities."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources


@dataclass
class CommoditySpec:
    yaml_key: str = "commodities"
    tres_subdir: str = "commodities"
    uid_prefix: str = "commodity"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "commodity_data": "res://data/definitions/commodity_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["commodity_id"]

    def build_label(self, entry: dict) -> str:
        return "commodity"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        commodity_id = entry["commodity_id"]
        uid = deterministic_uid(self.uid_prefix, commodity_id)
        ctx.uid_cache[commodity_id] = uid

        cat_id = entry.get("category_id")
        cat_uid = ctx.uid_cache.get(cat_id) if cat_id else None

        w = TresWriter("Resource", "CommodityData", uid)
        w.add_ext_resource(
            "1_commoditydef",
            "Script",
            "res://data/definitions/commodity_data.gd",
            ctx.script_uids["commodity_data"],
        )

        if cat_uid and cat_id:
            w.add_ext_resource(
                "2_cat",
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )

        w.add_field('script = ExtResource("1_commoditydef")')
        w.add_field_str("commodity_id", commodity_id)
        w.add_field_str("display_name", entry.get("display_name", commodity_id))
        w.add_field_ext_ref("category_data", "2_cat" if (cat_uid and cat_id) else None)
        w.add_field_int("base_value", int(entry.get("base_value", 0)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        commodity_id = tres_field(text, "commodity_id") or ""
        if uid:
            ctx.uid_to_id[uid] = commodity_id

        ext_res = ext_resources(text)
        category_id = ""
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_id = ctx.uid_to_id.get(cat_uid, "")

        return {
            "commodity_id": commodity_id,
            "display_name": tres_field(text, "display_name") or commodity_id,
            "category_id": category_id,
            "base_value": int(tres_field(text, "base_value") or 0),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }

        for commodity in entries:
            cid = commodity.get("commodity_id", "?")
            if commodity.get("category_id") not in known_cat_ids:
                errors.append(
                    f"commodity '{cid}': category_id '{commodity.get('category_id')}' not defined"
                )
            if int(commodity.get("base_value", 0)) < 0:
                errors.append(f"commodity '{cid}': base_value must be >= 0")

        return errors


SPEC = CommoditySpec()
