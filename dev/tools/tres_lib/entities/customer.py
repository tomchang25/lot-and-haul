"""EntitySpec for CustomerData resources."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field


@dataclass
class CustomerSpec:
    yaml_key: str = "customers"
    tres_subdir: str = "customers"
    uid_prefix: str = "customer"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "customer_data": "res://data/definitions/customer_data.gd",
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["customer_id"]

    def build_label(self, entry: dict) -> str:
        return "customer"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        customer_id = entry["customer_id"]
        uid = deterministic_uid(self.uid_prefix, customer_id)
        ctx.uid_cache[customer_id] = uid

        w = TresWriter("Resource", "CustomerData", uid)
        w.add_ext_resource(
            "1_custdef",
            "Script",
            "res://data/definitions/customer_data.gd",
            ctx.script_uids["customer_data"],
        )
        w.add_field('script = ExtResource("1_custdef")')
        w.add_field_str("customer_id", customer_id)
        w.add_field_str("display_name_key", entry.get("display_name_key", ""))
        w.add_field_str("appears_in_timeslot", entry.get("appears_in_timeslot", "any"))

        demand_pool: list[str] = entry.get("demand_pool", [])
        w.add_field_str_array("demand_pool", demand_pool)

        grid_pool: list = entry.get("grid_shape_pool", [])
        vec_parts: list[str] = []
        for g in grid_pool:
            if isinstance(g, (list, tuple)) and len(g) == 2:
                vec_parts.append(f"Vector2i({int(g[0])}, {int(g[1])})")
        w.add_field(f"grid_shape_pool = Array[Vector2i]([{', '.join(vec_parts)}])")

        valued_negative_tags: list[str] = entry.get("valued_negative_tags", [])
        w.add_field_str_array("valued_negative_tags", valued_negative_tags)

        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict | None:
        uid = header_uid(text)
        customer_id = tres_field(text, "customer_id") or ""
        if uid and customer_id:
            ctx.uid_to_id[uid] = customer_id
        return {
            "customer_id": customer_id,
            "display_name_key": tres_field(text, "display_name_key") or "",
            "appears_in_timeslot": tres_field(text, "appears_in_timeslot") or "any",
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()
        valid_timeslots = {"day", "night", "any"}
        shared_grid = {
            (2, 4),
            (3, 3),
            (4, 3),
            (4, 4),
            (5, 3),
            (5, 4),
            (5, 5),
            (6, 4),
            (6, 5),
            (6, 6),
        }

        all_clue_ids: set[str] = set()
        clues_by_id: dict[str, dict] = {}
        all_clues: list[dict] = all_data.get("clues", [])
        for clue in all_clues:
            cid = clue.get("clue_id", "")
            if cid:
                all_clue_ids.add(cid)
                clues_by_id[cid] = clue

        for customer in entries:
            customer_id = customer.get("customer_id", "")
            if not customer_id:
                errors.append("customer: customer_id is required")
                continue
            if customer_id in seen_ids:
                errors.append(f"customer '{customer_id}': duplicate customer_id")
            seen_ids.add(customer_id)

            display_name_key = customer.get("display_name_key", "")
            if not isinstance(display_name_key, str) or not display_name_key.strip():
                errors.append(f"customer '{customer_id}': display_name_key is required")

            timeslot = customer.get("appears_in_timeslot", "any")
            if timeslot not in valid_timeslots:
                errors.append(
                    f"customer '{customer_id}': appears_in_timeslot must be one of"
                    f" day/night/any, got '{timeslot}'"
                )

            demand_pool: list = customer.get("demand_pool", [])
            if not isinstance(demand_pool, list) or len(demand_pool) < 4:
                errors.append(
                    f"customer '{customer_id}': demand_pool must be a list of at"
                    f" least 4 clue ids"
                )

            for i, tag in enumerate(demand_pool):
                if not isinstance(tag, str) or not tag.strip():
                    errors.append(
                        f"customer '{customer_id}': demand_pool[{i}] is not a valid string"
                    )
                elif tag not in all_clue_ids:
                    errors.append(
                        f"customer '{customer_id}': demand_pool[{i}] '{tag}'"
                        f" does not match any clue_id"
                    )

            legal_unique_tags = {
                tag
                for tag in demand_pool
                if isinstance(tag, str) and tag in all_clue_ids
            }
            surface_count = sum(
                1
                for tag in legal_unique_tags
                if clues_by_id[tag].get("type", "surface") == "surface"
            )
            hidden_count = len(legal_unique_tags) - surface_count
            max_drawable_with_hidden_cap = surface_count + min(hidden_count, 1)
            if max_drawable_with_hidden_cap < 4:
                errors.append(
                    f"customer '{customer_id}': demand_pool cannot provide 4 unique"
                    f" tags while respecting the one-hidden-clue cap"
                )

            grid_pool: list = customer.get("grid_shape_pool", [])
            if not isinstance(grid_pool, list) or len(grid_pool) < 1:
                errors.append(
                    f"customer '{customer_id}': grid_shape_pool must be a"
                    f" non-empty list of [cols, rows] pairs"
                )
            for i, g in enumerate(grid_pool):
                if not isinstance(g, (list, tuple)) or len(g) != 2:
                    errors.append(
                        f"customer '{customer_id}': grid_shape_pool[{i}] must be"
                        f" a [cols, rows] pair"
                    )
                else:
                    cols, rows = int(g[0]), int(g[1])
                    if (cols, rows) not in shared_grid:
                        errors.append(
                            f"customer '{customer_id}': grid_shape_pool[{i}]"
                            f" [{cols}, {rows}] is not a shared grid shape"
                        )

            valued_negative_tags: list = customer.get("valued_negative_tags", [])
            if not isinstance(valued_negative_tags, list):
                errors.append(
                    f"customer '{customer_id}': valued_negative_tags must be a list"
                )
            for i, tag in enumerate(valued_negative_tags):
                if not isinstance(tag, str) or not tag.strip():
                    errors.append(
                        f"customer '{customer_id}': valued_negative_tags[{i}]"
                        f" is not a valid string"
                    )
                elif tag not in all_clue_ids:
                    errors.append(
                        f"customer '{customer_id}': valued_negative_tags[{i}]"
                        f" '{tag}' does not match any clue_id"
                    )
                else:
                    clue = clues_by_id[tag]
                    if clue.get("type", "surface") != "surface":
                        errors.append(
                            f"customer '{customer_id}': valued_negative_tags[{i}]"
                            f" '{tag}' must reference a surface clue"
                        )
                    if clue.get("effect_op", "") != "mul":
                        errors.append(
                            f"customer '{customer_id}': valued_negative_tags[{i}]"
                            f" '{tag}' must reference a mul clue"
                        )
                    try:
                        amount = float(clue.get("effect_amount", 1.0))
                    except (TypeError, ValueError):
                        amount = 1.0
                    if amount >= 1.0:
                        errors.append(
                            f"customer '{customer_id}': valued_negative_tags[{i}]"
                            f" '{tag}' must reference a negative multiplier clue"
                        )

        return errors


SPEC = CustomerSpec()
