"""EntitySpec for special order data."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter


@dataclass
class SpecialOrderDataSpec:
    yaml_key: str = "special_orders"
    tres_subdir: str = "special_orders"
    uid_prefix: str = "special_order"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "special_order_data": "res://data/definitions/special_order_data.gd",
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["special_order_id"]

    def build_label(self, entry: dict) -> str:
        return "special_order"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        so_id = entry["special_order_id"]
        uid = deterministic_uid(self.uid_prefix, so_id)
        ctx.uid_cache[so_id] = uid

        raw_cats = entry.get("allowed_categories", []) or []
        cat_ids = [str(c) for c in raw_cats]

        w = TresWriter("Resource", "SpecialOrderData", uid)
        w.add_ext_resource(
            "1_sodef",
            "Script",
            "res://data/definitions/special_order_data.gd",
            ctx.script_uids["special_order_data"],
        )

        ext_idx = 1
        cat_tags: list[str] = []
        for cat_id in cat_ids:
            ext_idx += 1
            tag = f"{ext_idx}_cat"
            cat_uid = ctx.uid_cache.get(cat_id, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )
            cat_tags.append(tag)

        w.add_field('script = ExtResource("1_sodef")')
        w.add_field_str("special_order_id", so_id)
        w.add_field_int("slot_count_min", int(entry.get("slot_count_min", 1)))
        w.add_field_int("slot_count_max", int(entry.get("slot_count_max", 1)))
        w.add_field_int("required_count_min", int(entry.get("required_count_min", 1)))
        w.add_field_int("required_count_max", int(entry.get("required_count_max", 1)))
        w.add_field_ext_ref_array("allowed_categories", cat_tags)
        w.add_field_float(
            "rarity_gate_chance",
            float(entry.get("rarity_gate_chance", 0.0)),
        )
        w.add_field_float(
            "condition_gate_chance",
            float(entry.get("condition_gate_chance", 0.0)),
        )
        w.add_field_float("buff_min", float(entry.get("buff_min", 1.0)))
        w.add_field_float("buff_max", float(entry.get("buff_max", 1.0)))
        w.add_field_bool(
            "uses_condition_pricing",
            bool(entry.get("uses_condition_pricing", False)),
        )
        w.add_field_bool(
            "allow_partial_delivery",
            bool(entry.get("allow_partial_delivery", False)),
        )
        w.add_field_int("completion_bonus", int(entry.get("completion_bonus", 0)))
        w.add_field_int("deadline_days", int(entry.get("deadline_days", 5)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> None:
        return None

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()
        known_cat_ids: set[str] = set()
        for cat in all_data.get("categories", []):
            if isinstance(cat, dict):
                known_cat_ids.add(cat["category_id"])

        for so in entries:
            so_id = so.get("special_order_id", "")
            if not so_id:
                errors.append("Special order missing special_order_id")
                continue
            if so_id in seen_ids:
                errors.append(f"Duplicate special_order_id: '{so_id}'")
            seen_ids.add(so_id)

            slot_min = so.get("slot_count_min", 1)
            slot_max = so.get("slot_count_max", 1)
            if not isinstance(slot_min, (int, float)) or int(slot_min) < 1:
                errors.append(
                    f"special_order '{so_id}': slot_count_min must be >= 1,"
                    f" got {slot_min!r}"
                )
            if not isinstance(slot_max, (int, float)) or int(slot_max) < 1:
                errors.append(
                    f"special_order '{so_id}': slot_count_max must be >= 1,"
                    f" got {slot_max!r}"
                )
            if (
                isinstance(slot_min, (int, float))
                and isinstance(slot_max, (int, float))
                and slot_min > slot_max
            ):
                errors.append(
                    f"special_order '{so_id}': slot_count_min ({slot_min})"
                    f" > slot_count_max ({slot_max})"
                )

            req_min = so.get("required_count_min", 1)
            req_max = so.get("required_count_max", 1)
            if not isinstance(req_min, (int, float)) or int(req_min) < 1:
                errors.append(
                    f"special_order '{so_id}': required_count_min must be >= 1,"
                    f" got {req_min!r}"
                )
            if not isinstance(req_max, (int, float)) or int(req_max) < 1:
                errors.append(
                    f"special_order '{so_id}': required_count_max must be >= 1,"
                    f" got {req_max!r}"
                )
            if (
                isinstance(req_min, (int, float))
                and isinstance(req_max, (int, float))
                and req_min > req_max
            ):
                errors.append(
                    f"special_order '{so_id}': required_count_min ({req_min})"
                    f" > required_count_max ({req_max})"
                )

            buff_min = so.get("buff_min", 1.0)
            buff_max = so.get("buff_max", 1.0)
            if not isinstance(buff_min, (int, float)) or buff_min < 0:
                errors.append(
                    f"special_order '{so_id}': buff_min must be >= 0,"
                    f" got {buff_min!r}"
                )
            if not isinstance(buff_max, (int, float)) or buff_max < 0:
                errors.append(
                    f"special_order '{so_id}': buff_max must be >= 0,"
                    f" got {buff_max!r}"
                )
            if (
                isinstance(buff_min, (int, float))
                and isinstance(buff_max, (int, float))
                and buff_min > buff_max
            ):
                errors.append(
                    f"special_order '{so_id}': buff_min ({buff_min})"
                    f" > buff_max ({buff_max})"
                )

            rarity_chance = so.get("rarity_gate_chance", 0.0)
            if not isinstance(rarity_chance, (int, float)) or not (
                0.0 <= rarity_chance <= 1.0
            ):
                errors.append(
                    f"special_order '{so_id}': rarity_gate_chance must be in [0, 1],"
                    f" got {rarity_chance!r}"
                )

            cond_chance = so.get("condition_gate_chance", 0.0)
            if not isinstance(cond_chance, (int, float)) or not (
                0.0 <= cond_chance <= 1.0
            ):
                errors.append(
                    f"special_order '{so_id}': condition_gate_chance must be in [0, 1],"
                    f" got {cond_chance!r}"
                )

            deadline = so.get("deadline_days", 5)
            if not isinstance(deadline, (int, float)) or int(deadline) < 1:
                errors.append(
                    f"special_order '{so_id}': deadline_days must be >= 1,"
                    f" got {deadline!r}"
                )

            bonus = so.get("completion_bonus", 0)
            if not isinstance(bonus, (int, float)) or int(bonus) < 0:
                errors.append(
                    f"special_order '{so_id}': completion_bonus must be >= 0,"
                    f" got {bonus!r}"
                )

            if known_cat_ids:
                for cat in so.get("allowed_categories", []) or []:
                    cat_id = str(cat)
                    if cat_id not in known_cat_ids:
                        errors.append(
                            f"special_order '{so_id}': allowed_category '{cat}'"
                            f" not defined in categories"
                        )

        return errors


SPEC = SpecialOrderDataSpec()
