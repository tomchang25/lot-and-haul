"""EntitySpec for merchants."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter


@dataclass
class MerchantSpec:
    yaml_key: str = "merchants"
    tres_subdir: str = "merchants"
    uid_prefix: str = "merchant"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "merchant_data": "res://data/definitions/merchant_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["merchant_id"]

    def build_label(self, entry: dict) -> str:
        return "merchant"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        mid = entry["merchant_id"]
        uid = deterministic_uid(self.uid_prefix, mid)
        ctx.uid_cache[mid] = uid

        raw_sc = entry.get("accepted_super_categories", []) or []
        sc_ids = [str(s) for s in raw_sc]
        so_ids = entry.get("special_order_pool", []) or []

        w = TresWriter("Resource", "MerchantData", uid)
        w.add_ext_resource(
            "1_mdef",
            "Script",
            "res://data/definitions/merchant_data.gd",
            ctx.script_uids["merchant_data"],
        )

        ext_idx = 1
        sc_tags: list[str] = []
        for sc_id in sc_ids:
            ext_idx += 1
            tag = f"{ext_idx}_sc"
            sc_uid = ctx.uid_cache.get(sc_id, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/super_categories/{sc_id}.tres",
                sc_uid,
            )
            sc_tags.append(tag)

        so_tags: list[str] = []
        for item_id in so_ids:
            ext_idx += 1
            tag = f"{ext_idx}_so"
            item_uid = ctx.uid_cache.get(item_id, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/items/{item_id}.tres",
                item_uid,
            )
            so_tags.append(tag)

        w.add_field('script = ExtResource("1_mdef")')
        w.add_field_str("merchant_id", mid)
        w.add_field_str("display_name", entry.get("display_name", ""))
        w.add_field_str("description", entry.get("description", ""))
        w.add_field_ext_ref_array("accepted_super_categories", sc_tags)
        w.add_field_float(
            "price_multiplier", float(entry.get("price_multiplier", 1.0))
        )
        w.add_field_bool(
            "accepts_off_category",
            bool(entry.get("accepts_off_category", False)),
        )
        w.add_field_float(
            "off_category_multiplier",
            float(entry.get("off_category_multiplier", 0.5)),
        )
        w.add_field_float(
            "accept_base_chance",
            float(entry.get("accept_base_chance", 0.8)),
        )
        w.add_field_float(
            "haggle_penalty_per_10pct",
            float(entry.get("haggle_penalty_per_10pct", 0.15)),
        )
        w.add_field_int(
            "max_counter_offers",
            int(entry.get("max_counter_offers", 2)),
        )
        w.add_field_ext_ref_array("special_order_pool", so_tags)
        w.add_field_int(
            "special_order_count",
            int(entry.get("special_order_count", 2)),
        )
        w.add_field_float(
            "special_order_bonus",
            float(entry.get("special_order_bonus", 0.25)),
        )
        w.add_field_str(
            "required_perk_id", entry.get("required_perk_id", "")
        )
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> None:
        return None

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()
        known_super_cat_ids: set[str] = set()
        for sc in all_data.get("super_categories", []):
            if isinstance(sc, dict):
                known_super_cat_ids.add(sc["super_category_id"])
            else:
                known_super_cat_ids.add(str(sc).lower().replace(" ", "_"))

        for merchant in entries:
            mid = merchant.get("merchant_id", "")
            if not mid:
                errors.append("Merchant missing merchant_id")
                continue
            if mid in seen_ids:
                errors.append(f"Duplicate merchant_id: '{mid}'")
            seen_ids.add(mid)

            if not merchant.get("display_name"):
                errors.append(f"merchant '{mid}': missing display_name")

            price_mult = merchant.get("price_multiplier", 1.0)
            if not isinstance(price_mult, (int, float)) or price_mult <= 0:
                errors.append(
                    f"merchant '{mid}': price_multiplier must be positive,"
                    f" got {price_mult!r}"
                )

            off_cat_mult = merchant.get("off_category_multiplier", 0.5)
            if not isinstance(off_cat_mult, (int, float)) or off_cat_mult < 0:
                errors.append(
                    f"merchant '{mid}': off_category_multiplier must be non-negative,"
                    f" got {off_cat_mult!r}"
                )

            accept_chance = merchant.get("accept_base_chance", 0.8)
            if not isinstance(accept_chance, (int, float)) or not (
                0.0 <= accept_chance <= 1.0
            ):
                errors.append(
                    f"merchant '{mid}': accept_base_chance must be between 0.0 and 1.0,"
                    f" got {accept_chance!r}"
                )

            if known_super_cat_ids:
                for sc in merchant.get("accepted_super_categories", []) or []:
                    sc_id = str(sc)
                    if sc_id not in known_super_cat_ids:
                        errors.append(
                            f"merchant '{mid}': accepted_super_category '{sc}'"
                            f" not defined in super_categories"
                        )

        return errors


SPEC = MerchantSpec()
