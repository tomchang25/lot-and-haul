"""EntitySpec for items."""

from __future__ import annotations

import re
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
        return f"item ({len(entry.get('layer_ids', []))} layers)"

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

        layer_tags: list[str] = []
        for i, lid in enumerate(entry.get("layer_ids", [])):
            tag = f"{3 + i}_layer"
            layer_uid = ctx.uid_cache.get(lid, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/identity_layers/{lid}.tres",
                layer_uid,
            )
            layer_tags.append(tag)

        cat_tag = "2_cat" if (cat_uid and cat_id) else None
        w.add_field('script = ExtResource("1_jyqit")')
        w.add_field_str("item_id", item_id)
        w.add_field_ext_ref("category_data", cat_tag)
        w.add_field_ext_ref_array("identity_layers", layer_tags)
        w.add_field_int("rarity", int(entry.get("rarity", 0)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        item_id = tres_field(text, "item_id") or ""
        if uid:
            ctx.uid_to_id[uid] = item_id

        rarity = int(tres_field(text, "rarity") or 0)

        ext_res = ext_resources(text)
        category_id = ""
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_id = ctx.uid_to_id.get(cat_uid, "")

        layer_ids: list[str] = []
        il_m = re.search(r"identity_layers\s*=\s*\[([^\]]*)\]", text)
        if il_m:
            for tag_m in re.finditer(r'ExtResource\("([^"]+)"\)', il_m.group(1)):
                layer_uid = ext_res.get(tag_m.group(1), {}).get("uid", "")
                lid = ctx.uid_to_id.get(layer_uid, "")
                if lid:
                    layer_ids.append(lid)

        return {
            "item_id": item_id,
            "category_id": category_id,
            "rarity": rarity,
            "layer_ids": layer_ids,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }
        layers = all_data.get("identity_layers", [])
        known_layer_ids: set[str] = {l["layer_id"] for l in layers}

        for item in entries:
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


SPEC = ItemSpec()
