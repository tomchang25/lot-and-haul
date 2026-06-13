"""EntitySpec for standalone anchor resources."""

from __future__ import annotations

from dataclasses import dataclass, field

_VALID_SHAPE_IDS: frozenset[str] = frozenset(
    {
        "s1x1",
        "s1x2",
        "s1x3",
        "s1x4",
        "s2x2",
        "s2x3",
        "s2x4",
        "sL11",
        "sL12",
        "sT3",
    }
)

import re

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources

SCRIPT_PATHS = {
    "anchor_data": "res://data/definitions/anchor_data.gd",
}


@dataclass
class AnchorSpec:
    yaml_key: str = "anchors"
    tres_subdir: str = "anchors"
    uid_prefix: str = "anchor"
    script_paths: dict[str, str] = field(default_factory=lambda: {**SCRIPT_PATHS})

    def entity_id(self, entry: dict) -> str:
        return entry["anchor_id"]

    def build_label(self, entry: dict) -> str:
        return "anchor"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        anchor_id = entry["anchor_id"]
        uid = deterministic_uid(self.uid_prefix, anchor_id)
        ctx.uid_cache[anchor_id] = uid

        cat_id = entry.get("category_scope", "")
        cat_uid = ctx.uid_cache.get(cat_id) if cat_id else None

        w = TresWriter("Resource", "AnchorData", uid)
        w.add_ext_resource(
            "1_anchordef",
            "Script",
            "res://data/definitions/anchor_data.gd",
            ctx.script_uids["anchor_data"],
        )
        if cat_uid and cat_id:
            w.add_ext_resource(
                "2_cat",
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )

        cat_tag = "2_cat" if (cat_uid and cat_id) else None

        w.add_field('script = ExtResource("1_anchordef")')
        w.add_field_str("anchor_id", anchor_id)
        w.add_field_str("known_text", entry.get("known_text", ""))
        w.add_field_ext_ref("category_data", cat_tag)
        w.add_field_float("base_value", float(entry.get("base_value", 0.0)))
        w.add_field_str("shape_id", entry.get("shape_id", "s1x1"))
        w.add_field_str("sprite", entry.get("sprite", ""))
        w.add_field_float("weight_kg", float(entry.get("weight_kg", 0.0)))
        w.add_field_int("tier", int(entry.get("tier", 1)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        anchor_id = tres_field(text, "anchor_id") or ""
        if uid:
            ctx.uid_to_id[uid] = anchor_id

        ext_res = ext_resources(text)
        category_scope = ""
        cat_m = re.search(r'\bcategory_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_scope = ctx.uid_to_id.get(cat_uid, "")

        return {
            "anchor_id": anchor_id,
            "known_text": tres_field(text, "known_text") or "",
            "category_scope": category_scope,
            "base_value": float(tres_field(text, "base_value") or 0.0),
            "shape_id": tres_field(text, "shape_id") or "s1x1",
            "sprite": tres_field(text, "sprite") or "",
            "weight_kg": float(tres_field(text, "weight_kg") or 0.0),
            "tier": int(tres_field(text, "tier") or 1),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: dict[str, int] = {}
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }

        for i, anchor in enumerate(entries):
            aid = anchor.get("anchor_id", "")
            if not aid:
                errors.append("anchor: anchor_id is required")
                continue
            if aid in seen_ids:
                errors.append(
                    f"anchor '{aid}': duplicate anchor_id (first seen at index {seen_ids[aid]})"
                )
            else:
                seen_ids[aid] = i

            cat_scope = anchor.get("category_scope", "")
            if not cat_scope:
                errors.append(f"anchor '{aid}': category_scope is required")
            elif cat_scope not in known_cat_ids:
                errors.append(
                    f"anchor '{aid}': category_scope '{cat_scope}' not in category table"
                )

            known_text = anchor.get("known_text", "")
            if not isinstance(known_text, str) or not known_text.strip():
                errors.append(f"anchor '{aid}': known_text is required")

            try:
                base_value = float(anchor.get("base_value", "MISSING"))
                if base_value <= 0.0:
                    errors.append(f"anchor '{aid}': base_value must be > 0")
            except (ValueError, TypeError):
                errors.append(f"anchor '{aid}': base_value is not a valid number")

            shape_id = anchor.get("shape_id", "")
            if not shape_id:
                errors.append(f"anchor '{aid}': shape_id is required")
            elif shape_id not in _VALID_SHAPE_IDS:
                errors.append(
                    f"anchor '{aid}': shape_id '{shape_id}' is invalid "
                    f"— valid: {sorted(_VALID_SHAPE_IDS)}"
                )

            weight_kg = anchor.get("weight_kg")
            try:
                if weight_kg is None or float(weight_kg) < 0.0:
                    errors.append(f"anchor '{aid}': weight_kg must be >= 0")
            except (ValueError, TypeError):
                errors.append(f"anchor '{aid}': weight_kg is not a valid number")

            tier = anchor.get("tier")
            try:
                if tier is None or not (1 <= int(tier) <= 5):
                    errors.append(f"anchor '{aid}': tier must be in range 1–5")
            except (ValueError, TypeError):
                errors.append(f"anchor '{aid}': tier is not a valid integer")

            # Three-word ceiling on known_text.
            if isinstance(known_text, str) and known_text.strip():
                word_count = len(known_text.split())
                if word_count > 3:
                    errors.append(
                        f"anchor '{aid}': known_text \"{known_text}\" has {word_count} words (max 3)"
                    )

        return errors


SPEC = AnchorSpec()
