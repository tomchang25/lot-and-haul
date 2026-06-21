"""EntitySpec for perks."""

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
class PerkSpec:
    yaml_key: str = "perks"
    tres_subdir: str = "perks"
    uid_prefix: str = "perk"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "perk_data": "res://data/definitions/perk_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["perk_id"]

    def build_label(self, entry: dict) -> str:
        return "perk"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        pid = entry["perk_id"]
        uid = deterministic_uid(self.uid_prefix, pid)
        ctx.uid_cache[pid] = uid

        w = TresWriter("Resource", "PerkData", uid)
        w.add_ext_resource(
            "1_perk",
            "Script",
            "res://data/definitions/perk_data.gd",
            ctx.script_uids["perk_data"],
        )

        w.add_field('script = ExtResource("1_perk")')
        w.add_field_str("perk_id", pid)
        w.add_field_str("display_name_key", entry.get("display_name_key", ""))
        w.add_field_str("description_key", entry.get("description_key", ""))
        w.add_field_str(
            "required_attribute", entry.get("required_attribute", "")
        )
        w.add_field_int(
            "required_attribute_value",
            int(entry.get("required_attribute_value", 0)),
        )
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        perk_id = tres_field(text, "perk_id") or ""
        if uid:
            ctx.uid_to_id[uid] = perk_id

        display_name_key = tres_field(text, "display_name_key") or perk_id
        description_key = tres_field(text, "description_key") or ""
        required_attribute = tres_field(text, "required_attribute") or ""
        required_attribute_value = int(tres_field(text, "required_attribute_value") or 0)

        return {
            "perk_id": perk_id,
            "display_name_key": display_name_key,
            "description_key": description_key,
            "required_attribute": required_attribute,
            "required_attribute_value": required_attribute_value,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_perk_ids: set[str] = set()

        for perk in entries:
            pid = perk.get("perk_id", "")
            if not pid:
                errors.append("Perk missing perk_id")
                continue
            if pid in seen_perk_ids:
                errors.append(f"Duplicate perk_id: '{pid}'")
            seen_perk_ids.add(pid)

            if not perk.get("display_name_key"):
                errors.append(f"Perk '{pid}': missing display_name_key")

            if not perk.get("description_key"):
                errors.append(f"Perk '{pid}': missing description_key")

        return errors


SPEC = PerkSpec()
