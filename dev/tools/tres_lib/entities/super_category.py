"""EntitySpec for super_categories."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field


_SNAKE_RE = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")


@dataclass
class SuperCategorySpec:
    yaml_key: str = "super_categories"
    tres_subdir: str = "super_categories"
    uid_prefix: str = "super_category"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "super_category_data": "res://data/definitions/super_category_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        if isinstance(entry, str):
            raise ValueError(
                f"Bare-string super_category entries are deprecated: '{entry}'. "
                "Use dict form with 'super_category_id' instead."
            )
        return entry["super_category_id"]

    def build_label(self, entry: dict) -> str:
        return "super_category"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        if isinstance(entry, str):
            raise ValueError(
                f"Bare-string super_category entries are deprecated: '{entry}'. "
                "Use dict form with 'super_category_id' instead."
            )
        super_category_id = entry["super_category_id"]
        display_name = entry.get("display_name", super_category_id)
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
        w.add_field_float(
            "market_mean_min",
            float(entry.get("market_mean_min", 0.7)),
        )
        w.add_field_float(
            "market_mean_max",
            float(entry.get("market_mean_max", 1.3)),
        )
        w.add_field_float(
            "market_stddev",
            float(entry.get("market_stddev", 0.02)),
        )
        w.add_field_float(
            "market_drift_per_day",
            float(entry.get("market_drift_per_day", 0.05)),
        )
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        super_cat_id = tres_field(text, "super_category_id") or ""
        display_name = tres_field(text, "display_name") or super_cat_id
        if uid:
            ctx.uid_to_id[uid] = super_cat_id
        ctx.super_cat_display_by_id[super_cat_id] = display_name

        market_mean_min = float(tres_field(text, "market_mean_min") or 0.7)
        market_mean_max = float(tres_field(text, "market_mean_max") or 1.3)
        market_stddev = float(tres_field(text, "market_stddev") or 0.02)
        market_drift_per_day = float(
            tres_field(text, "market_drift_per_day") or 0.05
        )

        return {
            "super_category_id": super_cat_id,
            "display_name": display_name,
            "market_mean_min": market_mean_min,
            "market_mean_max": market_mean_max,
            "market_stddev": market_stddev,
            "market_drift_per_day": market_drift_per_day,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()
        for entry in entries:
            if isinstance(entry, str):
                errors.append(
                    f"Bare-string super_category entry '{entry}' is "
                    "deprecated. Use dict form with 'super_category_id'."
                )
                continue

            sc_id = entry.get("super_category_id", "")
            if not sc_id:
                errors.append("super_category entry missing 'super_category_id'")
                continue

            if not _SNAKE_RE.match(sc_id):
                errors.append(
                    f"super_category '{sc_id}': super_category_id must be "
                    f"snake_case, got '{sc_id}'"
                )

            if sc_id in seen_ids:
                errors.append(f"Duplicate super_category_id: '{sc_id}'")
            seen_ids.add(sc_id)

            mean_min = entry.get("market_mean_min", 0.7)
            mean_max = entry.get("market_mean_max", 1.3)
            stddev = entry.get("market_stddev", 0.02)
            drift = entry.get("market_drift_per_day", 0.05)

            if not isinstance(mean_min, (int, float)) or not isinstance(
                mean_max, (int, float)
            ):
                errors.append(
                    f"super_category '{sc_id}': market_mean_min/max must be "
                    "numeric"
                )
            elif mean_min >= mean_max:
                errors.append(
                    f"super_category '{sc_id}': market_mean_min ({mean_min}) "
                    f"must be < market_mean_max ({mean_max})"
                )

            if not isinstance(stddev, (int, float)) or stddev <= 0:
                errors.append(
                    f"super_category '{sc_id}': market_stddev must be > 0, "
                    f"got {stddev!r}"
                )

            if not isinstance(drift, (int, float)) or drift < 0:
                errors.append(
                    f"super_category '{sc_id}': market_drift_per_day must be "
                    f">= 0, got {drift!r}"
                )

        return errors


SPEC = SuperCategorySpec()
