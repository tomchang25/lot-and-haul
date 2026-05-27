"""EntitySpec for attribute_data."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import (
    header_uid,
    field as tres_field,
)


@dataclass
class AttributeDataSpec:
    yaml_key: str = "attributes"
    tres_subdir: str = "attributes"
    uid_prefix: str = "attribute"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "attribute_data": "res://data/definitions/attribute_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["attribute_id"]

    def build_label(self, entry: dict) -> str:
        return "attribute"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        aid = entry["attribute_id"]
        uid = deterministic_uid(self.uid_prefix, aid)
        ctx.uid_cache[aid] = uid

        w = TresWriter("Resource", "AttributeData", uid)
        w.add_ext_resource(
            "1_attr",
            "Script",
            "res://data/definitions/attribute_data.gd",
            ctx.script_uids["attribute_data"],
        )

        w.add_field('script = ExtResource("1_attr")')
        w.add_field_str("attribute_id", aid)
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_int("starting_value", int(entry.get("starting_value", 1)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        attribute_id = tres_field(text, "attribute_id") or ""
        if uid:
            ctx.uid_to_id[uid] = attribute_id

        display_name = tres_field(text, "display_name") or attribute_id
        starting_value = int(tres_field(text, "starting_value") or 1)

        return {
            "attribute_id": attribute_id,
            "display_name": display_name,
            "starting_value": starting_value,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()

        for attr in entries:
            aid = attr.get("attribute_id", "")
            if not aid:
                errors.append("Attribute missing attribute_id")
                continue
            if aid in seen_ids:
                errors.append(f"Duplicate attribute_id: '{aid}'")
            seen_ids.add(aid)

            if not attr.get("display_name"):
                errors.append(f"Attribute '{aid}': missing display_name")

        return errors


SPEC = AttributeDataSpec()
