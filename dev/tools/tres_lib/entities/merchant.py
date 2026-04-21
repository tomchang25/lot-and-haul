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
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "merchant_data": "res://data/definitions/merchant_data.gd",
        }
    )

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
        so_ids = entry.get("special_orders", []) or []

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
        for so_id in so_ids:
            ext_idx += 1
            tag = f"{ext_idx}_so"
            so_uid = ctx.uid_cache.get(so_id, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/special_orders/{so_id}.tres",
                so_uid,
            )
            so_tags.append(tag)

        w.add_field('script = ExtResource("1_mdef")')
        w.add_field_str("merchant_id", mid)
        w.add_field_str("display_name", entry.get("display_name", ""))
        w.add_field_str("description", entry.get("description", ""))
        w.add_field_ext_ref_array("accepted_super_categories", sc_tags)
        w.add_field_float("price_multiplier", float(entry.get("price_multiplier", 1.0)))
        w.add_field_bool(
            "accepts_off_category",
            bool(entry.get("accepts_off_category", False)),
        )
        w.add_field_float(
            "off_category_multiplier",
            float(entry.get("off_category_multiplier", 0.5)),
        )
        w.add_field_float(
            "ceiling_multiplier_min",
            float(entry.get("ceiling_multiplier_min", 1.1)),
        )
        w.add_field_float(
            "ceiling_multiplier_max",
            float(entry.get("ceiling_multiplier_max", 1.3)),
        )
        w.add_field_float("anger_max", float(entry.get("anger_max", 100.0)))
        w.add_field_float("anger_k", float(entry.get("anger_k", 20.0)))
        w.add_field_float(
            "anger_per_round",
            float(entry.get("anger_per_round", 20.0)),
        )
        w.add_field_float(
            "counter_aggressiveness",
            float(entry.get("counter_aggressiveness", 0.3)),
        )
        w.add_field_float(
            "auto_accept_threshold",
            float(entry.get("auto_accept_threshold", 0.2)),
        )
        w.add_field_float(
            "auto_accept_p_min",
            float(entry.get("auto_accept_p_min", 0.01)),
        )
        w.add_field_int(
            "negotiation_per_day",
            int(entry.get("negotiation_per_day", 1)),
        )
        w.add_field_ext_ref_array("special_orders", so_tags)
        w.add_field_int(
            "order_roll_cadence",
            int(entry.get("order_roll_cadence", 0)),
        )
        w.add_field_int(
            "max_active_orders",
            int(entry.get("max_active_orders", 1)),
        )

        req_perk = entry.get("required_perk", "")
        if req_perk:
            ext_idx += 1
            perk_tag = f"{ext_idx}_perk"
            perk_uid = ctx.uid_cache.get(req_perk, "")
            w.add_ext_resource(
                perk_tag,
                "Resource",
                f"res://data/tres/perks/{req_perk}.tres",
                perk_uid,
            )
            w.add_field_ext_ref("required_perk", perk_tag)
        else:
            w.add_field("required_perk = null")

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

        known_perk_ids: set[str] = {
            p["perk_id"] for p in all_data.get("perks", []) if isinstance(p, dict) and p.get("perk_id")
        }

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

            ceiling_min = merchant.get("ceiling_multiplier_min", 1.1)
            ceiling_max = merchant.get("ceiling_multiplier_max", 1.3)
            if not isinstance(ceiling_min, (int, float)) or ceiling_min <= 0:
                errors.append(
                    f"merchant '{mid}': ceiling_multiplier_min must be positive,"
                    f" got {ceiling_min!r}"
                )
            if not isinstance(ceiling_max, (int, float)) or ceiling_max <= 0:
                errors.append(
                    f"merchant '{mid}': ceiling_multiplier_max must be positive,"
                    f" got {ceiling_max!r}"
                )
            if (
                isinstance(ceiling_min, (int, float))
                and isinstance(ceiling_max, (int, float))
                and ceiling_min > ceiling_max
            ):
                errors.append(
                    f"merchant '{mid}': ceiling_multiplier_min ({ceiling_min})"
                    f" > ceiling_multiplier_max ({ceiling_max})"
                )

            anger_max_val = merchant.get("anger_max", 100.0)
            if not isinstance(anger_max_val, (int, float)) or anger_max_val <= 0:
                errors.append(
                    f"merchant '{mid}': anger_max must be positive,"
                    f" got {anger_max_val!r}"
                )

            anger_k_val = merchant.get("anger_k", 20.0)
            if not isinstance(anger_k_val, (int, float)) or anger_k_val < 0:
                errors.append(
                    f"merchant '{mid}': anger_k must be non-negative,"
                    f" got {anger_k_val!r}"
                )

            anger_per_round_val = merchant.get("anger_per_round", 20.0)
            if (
                not isinstance(anger_per_round_val, (int, float))
                or anger_per_round_val < 0
            ):
                errors.append(
                    f"merchant '{mid}': anger_per_round must be non-negative,"
                    f" got {anger_per_round_val!r}"
                )

            counter_agg = merchant.get("counter_aggressiveness", 0.3)
            if not isinstance(counter_agg, (int, float)) or not (
                0.0 < counter_agg <= 1.0
            ):
                errors.append(
                    f"merchant '{mid}': counter_aggressiveness must be in (0, 1],"
                    f" got {counter_agg!r}"
                )

            aa_thresh = merchant.get("auto_accept_threshold", 0.2)
            if not isinstance(aa_thresh, (int, float)) or not (
                0.0 < aa_thresh < 1.0
            ):
                errors.append(
                    f"merchant '{mid}': auto_accept_threshold must be in (0, 1),"
                    f" got {aa_thresh!r}"
                )

            aa_p_min = merchant.get("auto_accept_p_min", 0.01)
            if not isinstance(aa_p_min, (int, float)) or not (
                0.0 <= aa_p_min <= 1.0
            ):
                errors.append(
                    f"merchant '{mid}': auto_accept_p_min must be in [0, 1],"
                    f" got {aa_p_min!r}"
                )

            neg_per_day = merchant.get("negotiation_per_day", 1)
            if not isinstance(neg_per_day, (int, float)) or int(neg_per_day) < 1:
                errors.append(
                    f"merchant '{mid}': negotiation_per_day must be >= 1,"
                    f" got {neg_per_day!r}"
                )

            if known_super_cat_ids:
                for sc in merchant.get("accepted_super_categories", []) or []:
                    sc_id = str(sc)
                    if sc_id not in known_super_cat_ids:
                        errors.append(
                            f"merchant '{mid}': accepted_super_category '{sc}'"
                            f" not defined in super_categories"
                        )

            order_cadence = merchant.get("order_roll_cadence", 0)
            if not isinstance(order_cadence, (int, float)) or int(order_cadence) < 0:
                errors.append(
                    f"merchant '{mid}': order_roll_cadence must be >= 0,"
                    f" got {order_cadence!r}"
                )

            max_orders = merchant.get("max_active_orders", 1)
            if not isinstance(max_orders, (int, float)) or not (
                0 <= int(max_orders) <= 3
            ):
                errors.append(
                    f"merchant '{mid}': max_active_orders must be in [0, 3],"
                    f" got {max_orders!r}"
                )

            known_so_ids: set[str] = set()
            for so in all_data.get("special_orders", []):
                if isinstance(so, dict):
                    known_so_ids.add(so["special_order_id"])

            if known_so_ids:
                for so_ref in merchant.get("special_orders", []) or []:
                    so_id = str(so_ref)
                    if so_id not in known_so_ids:
                        errors.append(
                            f"merchant '{mid}': special_order '{so_ref}'"
                            f" not defined in special_orders"
                        )

            req_perk = merchant.get("required_perk", "")
            if req_perk and known_perk_ids and req_perk not in known_perk_ids:
                errors.append(
                    f"merchant '{mid}': required_perk '{req_perk}'"
                    f" not defined in perks"
                )

        return errors


SPEC = MerchantSpec()
