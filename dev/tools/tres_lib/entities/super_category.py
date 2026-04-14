"""EntitySpec for super_categories."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field


@dataclass
class SuperCategorySpec:
    yaml_key: str = "super_categories"
    tres_subdir: str = "super_categories"
    uid_prefix: str = "super_category"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "super_category_data": "res://data/definitions/super_category_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["super_category_id"]

    def build_label(self, entry: dict) -> str:
        return "super_category"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        super_category_id = entry["super_category_id"]
        display_name = entry["display_name"]
        uid = deterministic_uid(self.uid_prefix, super_category_id)
        ctx.uid_cache[super_category_id] = uid

        w = TresWriter("Resource", "SuperCategoryData", uid)
        w.add_ext_resource(
            "1_superdef",
            "Script",
            "res://data/definitions/super_category_data.gd",
            ctx.script_uids["super_category_data"],
        )
        w.add_field('script = ExtResource("1_superdef")')
        w.add_field_str("super_category_id", super_category_id)
        w.add_field_str("display_name", display_name)
        w.add_field_float("market_mean_min", float(entry.get("market_mean_min", 0.7)))
        w.add_field_float("market_mean_max", float(entry.get("market_mean_max", 1.3)))
        w.add_field_float("market_stddev", float(entry.get("market_stddev", 0.08)))
        w.add_field_float("market_drift_per_day", float(entry.get("market_drift_per_day", 0.05)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        super_cat_id = tres_field(text, "super_category_id") or ""
        display_name = tres_field(text, "display_name") or super_cat_id
        if uid:
            ctx.uid_to_id[uid] = super_cat_id
        ctx.super_cat_display_by_id[super_cat_id] = display_name
        return {
            "super_category_id": super_cat_id,
            "display_name": display_name,
            "market_mean_min": float(tres_field(text, "market_mean_min") or 0.7),
            "market_mean_max": float(tres_field(text, "market_mean_max") or 1.3),
            "market_stddev": float(tres_field(text, "market_stddev") or 0.08),
            "market_drift_per_day": float(tres_field(text, "market_drift_per_day") or 0.05),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        for entry in entries:
            sid = entry.get("super_category_id", "?")
            lo = entry.get("market_mean_min", 0.7)
            hi = entry.get("market_mean_max", 1.3)
            if lo > hi:
                errors.append(
                    f"super_category '{sid}': market_mean_min ({lo}) > market_mean_max ({hi})"
                )
            if entry.get("market_stddev", 0.08) < 0:
                errors.append(f"super_category '{sid}': market_stddev must be >= 0")
            if entry.get("market_drift_per_day", 0.05) < 0:
                errors.append(f"super_category '{sid}': market_drift_per_day must be >= 0")
        return errors


SPEC = SuperCategorySpec()
