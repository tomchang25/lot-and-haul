"""EntitySpec for items."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources
from tres_lib.entities.clue_data import SCRIPT_PATHS as CLUE_DATA_SCRIPT_PATHS


def _gd_string(value: str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


@dataclass
class ItemSpec:
    yaml_key: str = "items"
    tres_subdir: str = "items"
    uid_prefix: str = "item"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "item_data": "res://data/definitions/item_data.gd",
        **CLUE_DATA_SCRIPT_PATHS,
    })

    def entity_id(self, entry: dict) -> str:
        return entry["item_id"]

    def build_label(self, entry: dict) -> str:
        clues = entry.get("clues", []) or []
        return f"item ({len(clues)} clues)"

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

        # -- Clue sub-resources --
        clues = entry.get("clues", []) or []
        clue_sub_ids: list[str] = []
        if clues:
            w.add_ext_resource(
                "3_clue",
                "Script",
                "res://data/definitions/clue_data.gd",
                ctx.script_uids["clue_data"],
            )
            for i, clue in enumerate(clues):
                sub_id = f"clue_{i}"
                clue_fields = [
                    'script = ExtResource("3_clue")',
                    f'clue_id = {_gd_string(clue.get("clue_id", ""))}',
                    f'known_text = {_gd_string(clue.get("known_text", ""))}',
                    f'type = {_gd_string(clue.get("type", "surface"))}',
                    f'domain = {_gd_string(clue.get("domain", "generic"))}',
                    f'attribute = {_gd_string(clue.get("attribute", ""))}',
                    f'dc = {int(clue.get("dc", 10))}',
                    f'price_effect = {_gd_string(clue.get("price_effect", ""))}',
                ]
                w.add_sub_resource(sub_id, "Resource", clue_fields)
                clue_sub_ids.append(sub_id)

        w.add_field('script = ExtResource("1_jyqit")')
        w.add_field_str("item_id", item_id)
        w.add_field_str("item_name", entry["item_name"])
        w.add_field_int("base_price", int(entry["base_price"]))
        w.add_field_ext_ref("category_data", cat_tag)
        w.add_field_sub_ref_array("clues", clue_sub_ids)
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

        # Parse clues from sub-resources
        subs = {}
        for m in re.finditer(
            r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[|$)',
            text,
            re.DOTALL,
        ):
            sid = m.group(1)
            body = m.group(2)
            fields = {}
            for fm in re.finditer(r'^(\w+)\s*=\s*(.+)$', body, re.MULTILINE):
                fields[fm.group(1)] = fm.group(2)
            subs[sid] = fields

        clues: list[dict] = []
        clues_raw = tres_field(text, "clues") or "[]"
        for cm in re.finditer(r'SubResource\("([^"]+)"\)', clues_raw):
            fields = subs.get(cm.group(1), {})
            clue = {
                "clue_id": fields.get("clue_id", "").strip('"'),
                "known_text": fields.get("known_text", "").strip('"'),
                "type": fields.get("type", "surface").strip('"'),
                "domain": fields.get("domain", "generic").strip('"'),
                "attribute": fields.get("attribute", "").strip('"'),
                "dc": int(fields.get("dc", "10")),
                "price_effect": fields.get("price_effect", "").strip('"'),
            }
            clues.append(clue)

        return {
            "item_id": item_id,
            "item_name": item_name,
            "base_price": base_price,
            "category_id": category_id,
            "rarity": rarity,
            "auto_verify": auto_verify,
            "clues": clues,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }
        known_tags: set[str] = {
            t for t_list in all_data.get("tags", [])
            for t in (t_list if isinstance(t_list, list) else [t_list])
        } if "tags" in all_data else set()

        for item in entries:
            iid = item.get("item_id", "?")
            clues = item.get("clues", []) or []
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

            if not isinstance(clues, list):
                errors.append(f"item '{iid}': clues must be a list")
                continue

            if not clues:
                errors.append(f"item '{iid}': must have at least one clue")
                continue

            anchor_count = sum(1 for c in clues if c.get("type") == "anchor")
            if anchor_count != 1:
                errors.append(
                    f"item '{iid}': must have exactly 1 anchor clue, found {anchor_count}"
                )

            # Validate clue ids against tag vocabulary
            if known_tags:
                for clue in clues:
                    cid = clue.get("clue_id", "")
                    if cid and cid not in known_tags:
                        errors.append(
                            f"item '{iid}': clue_id '{cid}' not found in tags vocabulary"
                        )

            # Validate required fields per clue
            for clue in clues:
                cid = clue.get("clue_id", "") if isinstance(clue, dict) else ""
                if not cid:
                    errors.append(f"item '{iid}': clue_id is required")
                    continue

                known_text = clue.get("known_text", "")
                if not isinstance(known_text, str) or not known_text.strip():
                    errors.append(f"item '{iid}', clue '{cid}': known_text is required")

                ctype = clue.get("type", "")
                if ctype not in ("anchor", "surface", "hidden"):
                    errors.append(
                        f"item '{iid}', clue '{cid}': type must be anchor/surface/hidden"
                    )

        return errors


SPEC = ItemSpec()
