"""EntitySpec for items."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources


@dataclass
class ItemSpec:
    yaml_key: str = "items"
    tres_subdir: str = "items"
    uid_prefix: str = "item"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "item_data": "res://data/definitions/item_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["item_id"]

    def build_label(self, entry: dict) -> str:
        clue_ids = entry.get("clue_ids", []) or []
        return f"item ({len(clue_ids)} clues)"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        item_id = entry["item_id"]
        uid = deterministic_uid(self.uid_prefix, item_id)
        ctx.uid_cache[item_id] = uid

        cat_id = entry.get("category_id")
        cat_uid = ctx.uid_cache.get(cat_id) if cat_id else None

        w = TresWriter("Resource", "ItemData", uid)
        w.add_ext_resource(
            "1_jyqit",
            "Script",
            "res://data/definitions/item_data.gd",
            ctx.script_uids["item_data"],
        )

        if cat_uid and cat_id:
            w.add_ext_resource(
                "2_cat",
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )

        cat_tag = "2_cat" if (cat_uid and cat_id) else None

        # -- Clue ExtResource links --
        clue_ids = entry.get("clue_ids", []) or []
        clue_ext_tags: list[str] = []
        for i, clue_id in enumerate(clue_ids):
            clue_uid = ctx.uid_cache.get(clue_id)
            if clue_uid is None:
                print(f"ERROR: item '{item_id}': clue_id '{clue_id}' not found in uid_cache", file=sys.stderr)
                continue
            ext_tag = f"clue_{i}"
            w.add_ext_resource(
                ext_tag,
                "Resource",
                f"res://data/tres/clues/{clue_id}.tres",
                clue_uid,
            )
            clue_ext_tags.append(ext_tag)

        w.add_field('script = ExtResource("1_jyqit")')
        w.add_field_str("item_id", item_id)
        w.add_field_str("item_name", entry["item_name"])
        w.add_field_int("base_price", int(entry["base_price"]))
        w.add_field_ext_ref("category_data", cat_tag)
        w.add_field_ext_ref_array("clues", clue_ext_tags)
        w.add_field_int("rarity", int(entry.get("rarity", 0)))
        w.add_field_bool("auto_verify", bool(entry.get("auto_verify", False)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        item_id = tres_field(text, "item_id") or ""
        item_name = tres_field(text, "item_name") or ""
        base_price = int(tres_field(text, "base_price") or 0)
        if uid:
            ctx.uid_to_id[uid] = item_id

        rarity = int(tres_field(text, "rarity") or 0)
        auto_verify = (tres_field(text, "auto_verify") or "false").strip().lower() == "true"

        ext_res = ext_resources(text)
        category_id = ""
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_id = ctx.uid_to_id.get(cat_uid, "")

        # Parse clue_ids from ExtResource references
        clue_ids: list[str] = []
        clues_raw = tres_field(text, "clues") or "[]"
        for cm in re.finditer(r'ExtResource\("([^"]+)"\)', clues_raw):
            ext_tag = cm.group(1)
            ext_info = ext_res.get(ext_tag, {})
            ext_path = ext_info.get("path", "")
            if "/tres/clues/" in ext_path:
                cid = ext_path.rsplit("/", 1)[-1].replace(".tres", "")
                clue_ids.append(cid)

        return {
            "item_id": item_id,
            "item_name": item_name,
            "base_price": base_price,
            "category_id": category_id,
            "rarity": rarity,
            "auto_verify": auto_verify,
            "clue_ids": clue_ids,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }
        known_clues_by_id: dict[str, dict] = {
            c["clue_id"]: c for c in all_data.get("clues", [])
        }

        for item in entries:
            iid = item.get("item_id", "?")
            clue_ids = item.get("clue_ids", []) or []
            rarity = int(item.get("rarity", 0))
            auto_verify = bool(item.get("auto_verify", False))
            item_name = item.get("item_name")
            base_price = item.get("base_price")

            if not isinstance(item_name, str) or not item_name.strip():
                errors.append(f"item '{iid}': item_name is required")

            if type(base_price) is not int or base_price <= 0:
                errors.append(f"item '{iid}': base_price must be a positive int")

            if item.get("category_id") not in known_cat_ids:
                errors.append(
                    f"item '{iid}': category_id '{item.get('category_id')}' not defined"
                )

            if not isinstance(clue_ids, list):
                errors.append(f"item '{iid}': clue_ids must be a list")
                continue

            if not clue_ids:
                errors.append(f"item '{iid}': must have at least one clue")
                continue

            # Validate clue ids against clue table
            for cid in clue_ids:
                if cid not in known_clues_by_id:
                    errors.append(
                        f"item '{iid}': clue_id '{cid}' not in clue table"
                    )

            # Validate anchor count by cross-referencing clue table
            anchors = [
                cid for cid in clue_ids
                if known_clues_by_id.get(cid, {}).get("type") == "anchor"
            ]
            if len(anchors) != 1:
                errors.append(
                    f"item '{iid}': must have exactly 1 anchor clue, found {len(anchors)}"
                )

        return errors


SPEC = ItemSpec()
