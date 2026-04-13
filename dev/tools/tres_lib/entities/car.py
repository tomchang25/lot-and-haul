"""EntitySpec for cars."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter


@dataclass
class CarSpec:
    yaml_key: str = "cars"
    tres_subdir: str = "cars"
    uid_prefix: str = "car"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "car_data": "res://data/definitions/car_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["car_id"]

    def build_label(self, entry: dict) -> str:
        return "car"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        car_id = entry["car_id"]
        uid = deterministic_uid(self.uid_prefix, car_id)
        ctx.uid_cache[car_id] = uid

        icon_path = str(entry.get("icon", ""))
        has_icon = bool(icon_path)
        load_steps = 3 if has_icon else 2

        w = TresWriter("Resource", "CarData", uid, load_steps=load_steps)
        w.add_ext_resource(
            "1_cardef",
            "Script",
            "res://data/definitions/car_data.gd",
            ctx.script_uids["car_data"],
        )

        if has_icon:
            w.add_ext_resource("2_icon", "Texture2D", icon_path)

        w.add_field('script = ExtResource("1_cardef")')
        w.add_field_str("car_id", car_id)
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_int("grid_columns", int(entry["grid_columns"]))
        w.add_field_int("grid_rows", int(entry["grid_rows"]))
        w.add_field_float("max_weight", float(entry["max_weight"]))
        w.add_field_int("stamina_cap", int(entry["stamina_cap"]))
        w.add_field_int("fuel_cost_per_day", int(entry.get("fuel_cost_per_day", 0)))
        w.add_field_int("extra_slot_count", int(entry.get("extra_slot_count", 0)))
        w.add_field_int("price", int(entry.get("price", 0)))

        if has_icon:
            w.add_field('icon = ExtResource("2_icon")')

        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> None:
        return None

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_car_ids: set[str] = set()

        for car in entries:
            car_id = car.get("car_id", "")
            if not car_id:
                errors.append("Car missing car_id")
                continue
            if car_id in seen_car_ids:
                errors.append(f"Duplicate car_id: '{car_id}'")
            seen_car_ids.add(car_id)

            grid_columns = car.get("grid_columns")
            if not isinstance(grid_columns, int) or grid_columns <= 0:
                errors.append(
                    f"car '{car_id}': grid_columns must be a positive integer,"
                    f" got {grid_columns!r}"
                )

            grid_rows = car.get("grid_rows")
            if not isinstance(grid_rows, int) or grid_rows <= 0:
                errors.append(
                    f"car '{car_id}': grid_rows must be a positive integer,"
                    f" got {grid_rows!r}"
                )

            max_weight = car.get("max_weight")
            if not isinstance(max_weight, (int, float)) or max_weight <= 0:
                errors.append(
                    f"car '{car_id}': max_weight must be a positive number,"
                    f" got {max_weight!r}"
                )

            stamina_cap = car.get("stamina_cap")
            if not isinstance(stamina_cap, int) or stamina_cap <= 0:
                errors.append(
                    f"car '{car_id}': stamina_cap must be a positive integer,"
                    f" got {stamina_cap!r}"
                )

            fuel_cost_per_day = car.get("fuel_cost_per_day", 0)
            if not isinstance(fuel_cost_per_day, int) or fuel_cost_per_day < 0:
                errors.append(
                    f"car '{car_id}': fuel_cost_per_day must be a non-negative"
                    f" integer, got {fuel_cost_per_day!r}"
                )

            extra_slot_count = car.get("extra_slot_count", 0)
            if not isinstance(extra_slot_count, int) or extra_slot_count < 0:
                errors.append(
                    f"car '{car_id}': extra_slot_count must be a non-negative"
                    f" integer, got {extra_slot_count!r}"
                )

        return errors


SPEC = CarSpec()
