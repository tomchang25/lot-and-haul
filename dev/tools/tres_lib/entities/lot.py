"""EntitySpec for lots."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter, format_dict_auto_keys
from tres_lib.tres_format import header_uid, field as tres_field, parse_godot_dict


@dataclass
class LotSpec:
    yaml_key: str = "lots"
    tres_subdir: str = "lots"
    uid_prefix: str = "lot"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "lot_data": "res://data/definitions/lot_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["lot_id"]

    def build_label(self, entry: dict) -> str:
        return "lot"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        lot_id = entry["lot_id"]
        uid = deterministic_uid(self.uid_prefix, lot_id)
        ctx.uid_cache[lot_id] = uid

        w = TresWriter("Resource", "LotData", uid)
        w.add_ext_resource(
            "1_lotdef",
            "Script",
            "res://data/definitions/lot_data.gd",
            ctx.script_uids["lot_data"],
        )
        w.add_field('script = ExtResource("1_lotdef")')
        w.add_field_str("lot_id", lot_id)
        w.add_field_float(
            "aggressive_factor_min",
            float(entry.get("aggressive_factor_min", 0.3)),
        )
        w.add_field_float(
            "aggressive_factor_max",
            float(entry.get("aggressive_factor_max", 0.7)),
        )
        w.add_field_float(
            "aggressive_lerp_min",
            float(entry.get("aggressive_lerp_min", 0.8)),
        )
        w.add_field_float(
            "aggressive_lerp_max",
            float(entry.get("aggressive_lerp_max", 1.2)),
        )
        w.add_field_float(
            "npc_layer_sight_chance",
            float(entry.get("npc_layer_sight_chance", 0.5)),
        )
        w.add_field_float(
            "opening_bid_factor",
            float(entry.get("opening_bid_factor", 0.25)),
        )
        w.add_field_float(
            "veiled_chance", float(entry.get("veiled_chance", 0.4))
        )
        w.add_field_int(
            "item_count_min", int(entry.get("item_count_min", 3))
        )
        w.add_field_int(
            "item_count_max", int(entry.get("item_count_max", 5))
        )
        w.add_field_dict_auto_keys(
            "rarity_weights", entry.get("rarity_weights", {}) or {}
        )
        w.add_field_dict_auto_keys(
            "super_category_weights",
            entry.get("super_category_weights", {}) or {},
        )
        w.add_field_dict_auto_keys(
            "category_weights", entry.get("category_weights", {}) or {}
        )
        w.add_field_float(
            "price_floor_factor",
            float(entry.get("price_floor_factor", 0.6)),
        )
        w.add_field_float(
            "price_ceiling_factor",
            float(entry.get("price_ceiling_factor", 1.4)),
        )
        w.add_field_float(
            "price_variance_min",
            float(entry.get("price_variance_min", 0.85)),
        )
        w.add_field_float(
            "price_variance_max",
            float(entry.get("price_variance_max", 1.15)),
        )
        w.add_field_int("action_quota", int(entry.get("action_quota", 6)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        lot_id = tres_field(text, "lot_id") or ""
        if uid:
            ctx.uid_to_id[uid] = lot_id

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

        lot: dict = {"lot_id": lot_id}
        for key in _FLOAT_FIELDS:
            val = tres_field(text, key)
            if val is not None:
                lot[key] = float(val)
        for key in _INT_FIELDS:
            val = tres_field(text, key)
            if val is not None:
                lot[key] = int(val)
        for key in _DICT_FIELDS:
            val = tres_field(text, key)
            if val is not None:
                lot[key] = parse_godot_dict(val)

        return lot

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }
        known_super_cat_ids: set[str] = {
            sc["super_category_id"]
            for sc in all_data.get("super_categories", [])
            if isinstance(sc, dict)
        }

        for lot in entries:
            lot_id = lot.get("lot_id", "?")

            for key in (lot.get("category_weights") or {}).keys():
                if key not in known_cat_ids:
                    errors.append(
                        f"lot '{lot_id}': category_weights key '{key}' not defined in categories"
                    )

            for key in (lot.get("super_category_weights") or {}).keys():
                if key not in known_super_cat_ids:
                    errors.append(
                        f"lot '{lot_id}': super_category_weights key '{key}' not defined in super_categories"
                    )

        return errors


SPEC = LotSpec()
