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
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_str("description", entry["description"])
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        perk_id = tres_field(text, "perk_id") or ""
        if uid:
            ctx.uid_to_id[uid] = perk_id

        display_name = tres_field(text, "display_name") or perk_id
        description = tres_field(text, "description") or ""

        return {
            "perk_id": perk_id,
            "display_name": display_name,
            "description": description,
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

            if not perk.get("display_name"):
                errors.append(f"Perk '{pid}': missing display_name")

            if not perk.get("description"):
                errors.append(f"Perk '{pid}': missing description")

        return errors


SPEC = PerkSpec()
