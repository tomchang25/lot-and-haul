"""EntitySpec for special order data."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter


# Pricing preset strings accepted in YAML / SpecialOrderData.pricing_mode.
# Must stay in sync with SpecialOrder.PRICING_MODE_* constants.
VALID_PRICING_MODES: frozenset[str] = frozenset(
    {"flat", "condition", "appraised", "market"}
)

# Max value for SpecialOrderSlotData.rarity_floor (ItemData.Rarity.LEGENDARY).
RARITY_FLOOR_MAX: int = 4


@dataclass
class SpecialOrderDataSpec:
    yaml_key: str = "special_orders"
    tres_subdir: str = "special_orders"
    uid_prefix: str = "special_order"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "special_order_data": "res://data/definitions/special_order_data.gd",
            "special_order_slot_data": (
                "res://data/definitions/special_order_slot_data.gd"
            ),
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

        slot_pool = entry.get("slot_pool", []) or []

        # Gather every unique category referenced across the whole pool so the
        # .tres lists each ext_resource exactly once.
        cat_tag_by_id: dict[str, str] = {}
        ext_idx = 1  # 1 is the script ext_resource below
        for pool_entry in slot_pool:
            for raw_cat in pool_entry.get("categories", []) or []:
                cat_id = str(raw_cat)
                if cat_id in cat_tag_by_id:
                    continue
                ext_idx += 1
                tag = f"{ext_idx}_cat"
                cat_uid = ctx.uid_cache.get(cat_id, "")
                cat_tag_by_id[cat_id] = tag

        w = TresWriter("Resource", "SpecialOrderData", uid)
        w.add_ext_resource(
            "1_sodef",
            "Script",
            "res://data/definitions/special_order_data.gd",
            ctx.script_uids["special_order_data"],
        )
        slot_script_tag = "2_slotdef" if slot_pool else None
        if slot_script_tag:
            w.add_ext_resource(
                slot_script_tag,
                "Script",
                "res://data/definitions/special_order_slot_data.gd",
                ctx.script_uids["special_order_slot_data"],
            )
        for cat_id, tag in cat_tag_by_id.items():
            cat_uid = ctx.uid_cache.get(cat_id, "")
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )

        # Emit one sub_resource per pool entry.
        sub_ids: list[str] = []
        for i, pool_entry in enumerate(slot_pool):
            sub_id = f"slot_{i}"
            cat_refs = ", ".join(
                f'ExtResource("{cat_tag_by_id[str(c)]}")'
                for c in pool_entry.get("categories", []) or []
            )
            sub_fields = [
                f'script = ExtResource("{slot_script_tag}")',
                f"categories = [{cat_refs}]",
                f'rarity_floor = {int(pool_entry.get("rarity_floor", -1))}',
                f'condition_floor = {float(pool_entry.get("condition_floor", 0.0))}',
                f'count_min = {int(pool_entry.get("count_min", 1))}',
                f'count_max = {int(pool_entry.get("count_max", 1))}',
            ]
            w.add_sub_resource(sub_id, "Resource", sub_fields)
            sub_ids.append(sub_id)

        w.add_field('script = ExtResource("1_sodef")')
        w.add_field_str("special_order_id", so_id)
        w.add_field_int("slot_count_min", int(entry.get("slot_count_min", 1)))
        w.add_field_int("slot_count_max", int(entry.get("slot_count_max", 1)))
        w.add_field_sub_ref_array("slot_pool", sub_ids)
        w.add_field_float("buff_min", float(entry.get("buff_min", 1.0)))
        w.add_field_float("buff_max", float(entry.get("buff_max", 1.0)))
        w.add_field_str("pricing_mode", str(entry.get("pricing_mode", "flat")))
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

            pricing_mode = so.get("pricing_mode", "flat")
            if pricing_mode not in VALID_PRICING_MODES:
                errors.append(
                    f"special_order '{so_id}': pricing_mode must be one of"
                    f" {sorted(VALID_PRICING_MODES)}, got {pricing_mode!r}"
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

            slot_pool = so.get("slot_pool", []) or []
            if not slot_pool:
                errors.append(
                    f"special_order '{so_id}': slot_pool must have at least"
                    f" one entry"
                )
                continue

            for i, pool_entry in enumerate(slot_pool):
                label = f"special_order '{so_id}' slot_pool[{i}]"
                if not isinstance(pool_entry, dict):
                    errors.append(f"{label}: must be a mapping")
                    continue

                cats = pool_entry.get("categories", []) or []
                if not cats:
                    errors.append(f"{label}: categories must be non-empty")
                elif known_cat_ids:
                    for cat in cats:
                        cat_id = str(cat)
                        if cat_id not in known_cat_ids:
                            errors.append(
                                f"{label}: category '{cat}' not defined in"
                                f" categories"
                            )

                rarity_floor = pool_entry.get("rarity_floor", -1)
                if not isinstance(rarity_floor, (int, float)) or not (
                    -1 <= int(rarity_floor) <= RARITY_FLOOR_MAX
                ):
                    errors.append(
                        f"{label}: rarity_floor must be in [-1, "
                        f"{RARITY_FLOOR_MAX}], got {rarity_floor!r}"
                    )

                cond_floor = pool_entry.get("condition_floor", 0.0)
                if not isinstance(cond_floor, (int, float)) or not (
                    0.0 <= float(cond_floor) <= 1.0
                ):
                    errors.append(
                        f"{label}: condition_floor must be in [0, 1],"
                        f" got {cond_floor!r}"
                    )

                count_min = pool_entry.get("count_min", 1)
                count_max = pool_entry.get("count_max", 1)
                if not isinstance(count_min, (int, float)) or int(count_min) < 1:
                    errors.append(
                        f"{label}: count_min must be >= 1, got {count_min!r}"
                    )
                if not isinstance(count_max, (int, float)) or int(count_max) < 1:
                    errors.append(
                        f"{label}: count_max must be >= 1, got {count_max!r}"
                    )
                if (
                    isinstance(count_min, (int, float))
                    and isinstance(count_max, (int, float))
                    and int(count_min) > int(count_max)
                ):
                    errors.append(
                        f"{label}: count_min ({count_min}) >"
                        f" count_max ({count_max})"
                    )

        return errors


SPEC = SpecialOrderDataSpec()
