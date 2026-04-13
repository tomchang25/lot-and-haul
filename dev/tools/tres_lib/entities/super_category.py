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

    def entity_id(self, entry: str) -> str:
        return str(entry).lower().replace(" ", "_")

    def build_label(self, entry: str) -> str:
        return "super_category"

    def build_tres(self, entry: str, ctx: BuildCtx) -> str:
        display_name = str(entry)
        super_category_id = self.entity_id(entry)
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
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> str:
        uid = header_uid(text)
        super_cat_id = tres_field(text, "super_category_id") or ""
        display_name = tres_field(text, "display_name") or super_cat_id
        if uid:
            ctx.uid_to_id[uid] = super_cat_id
        ctx.super_cat_display_by_id[super_cat_id] = display_name
        return display_name

    def validate(self, entries: list, all_data: dict) -> list[str]:
        return []


SPEC = SuperCategorySpec()
