"""EntitySpec for locations."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources


@dataclass
class LocationSpec:
    yaml_key: str = "locations"
    tres_subdir: str = "locations"
    uid_prefix: str = "location"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "location_data": "res://data/definitions/location_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["location_id"]

    def build_label(self, entry: dict) -> str:
        return f"location ({len(entry.get('lot_pool', []) or [])} lots)"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        location_id = entry["location_id"]
        uid = deterministic_uid(self.uid_prefix, location_id)
        ctx.uid_cache[location_id] = uid

        lot_ids: list[str] = entry.get("lot_pool", []) or []

        w = TresWriter("Resource", "LocationData", uid)
        w.add_ext_resource(
            "1_locdef",
            "Script",
            "res://data/definitions/location_data.gd",
            ctx.script_uids["location_data"],
        )

        lot_tags: list[str] = []
        for i, lid in enumerate(lot_ids):
            lot_uid = ctx.uid_cache.get(lid, "")
            tag = f"{2 + i}_lot"
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/lots/{lid}.tres",
                lot_uid,
            )
            lot_tags.append(tag)

        w.add_field('script = ExtResource("1_locdef")')
        w.add_field_str("location_id", location_id)
        w.add_field_str("display_name", entry.get("display_name", ""))
        w.add_field_str("description", entry.get("description", ""))
        w.add_field_int("entry_fee", int(entry.get("entry_fee", 0)))
        w.add_field_int("travel_days", int(entry.get("travel_days", 1)))
        w.add_field_int("lot_number", int(entry.get("lot_number", 3)))
        w.add_field_ext_ref_array("lot_pool", lot_tags)
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        location_id = tres_field(text, "location_id") or ""
        if uid:
            ctx.uid_to_id[uid] = location_id

        display_name = tres_field(text, "display_name") or location_id
        description = tres_field(text, "description") or ""
        entry_fee = int(tres_field(text, "entry_fee") or 0)
        travel_days = int(tres_field(text, "travel_days") or 1)
        lot_number = int(tres_field(text, "lot_number") or 3)

        ext_res = ext_resources(text)

        lot_ids: list[str] = []
        lp_m = re.search(r"lot_pool\s*=\s*\[([^\]]*)\]", text)
        if lp_m:
            for tag_m in re.finditer(
                r'ExtResource\("([^"]+)"\)', lp_m.group(1)
            ):
                lot_uid = ext_res.get(tag_m.group(1), {}).get("uid", "")
                lid = ctx.uid_to_id.get(lot_uid, "")
                if lid:
                    lot_ids.append(lid)

        return {
            "location_id": location_id,
            "display_name": display_name,
            "description": description,
            "entry_fee": entry_fee,
            "travel_days": travel_days,
            "lot_number": lot_number,
            "lot_pool": lot_ids,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        return []


SPEC = LocationSpec()
