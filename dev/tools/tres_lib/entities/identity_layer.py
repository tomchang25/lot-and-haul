"""EntitySpec for identity_layers."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import (
    header_uid,
    field as tres_field,
    sub_resources,
    ext_resources,
)


@dataclass
class IdentityLayerSpec:
    yaml_key: str = "identity_layers"
    tres_subdir: str = "identity_layers"
    uid_prefix: str = "identity_layer"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "identity_layer": "res://data/definitions/identity_layer.gd",
        "layer_unlock_action": "res://data/definitions/layer_unlock_action.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["layer_id"]

    def build_label(self, entry: dict) -> str:
        return "layer"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        layer_id = entry["layer_id"]
        uid = deterministic_uid(self.uid_prefix, layer_id)
        ctx.uid_cache[layer_id] = uid

        # Store layer data for cross-entity use (items need it)
        ctx.identity_layers_by_id[layer_id] = entry

        unlock = entry.get("unlock_action")

        w = TresWriter("Resource", "IdentityLayer", uid)
        w.add_ext_resource(
            "1_ilay",
            "Script",
            "res://data/definitions/identity_layer.gd",
            ctx.script_uids["identity_layer"],
        )

        if unlock is not None:
            w.add_ext_resource(
                "2_unlock",
                "Script",
                "res://data/definitions/layer_unlock_action.gd",
                ctx.script_uids["layer_unlock_action"],
            )

            skill_tag: str | None = None
            sid = unlock.get("required_skill")
            if sid:
                suid = ctx.uid_cache.get(sid)
                if suid:
                    w.add_ext_resource(
                        "3_skill",
                        "Resource",
                        f"res://data/tres/skills/{sid}.tres",
                        suid,
                    )
                    skill_tag = "3_skill"

            skill_ref = f'ExtResource("{skill_tag}")' if skill_tag else "null"
            sub_fields = [
                'script = ExtResource("2_unlock")',
                f'difficulty = {float(unlock.get("difficulty", 1.0))}',
            ]
            if skill_tag:
                sub_fields.append(f"required_skill = {skill_ref}")
                sub_fields.append(
                    f'required_level = {int(unlock.get("required_level", 0))}'
                )
            if float(unlock.get("required_condition", 0.0)) != 0.0:
                sub_fields.append(
                    f'required_condition = {float(unlock["required_condition"])}'
                )
            if int(unlock.get("required_category_rank", 0)) != 0:
                sub_fields.append(
                    f'required_category_rank = {int(unlock["required_category_rank"])}'
                )
            if unlock.get("required_perk_id", ""):
                sub_fields.append(
                    f'required_perk_id = "{unlock["required_perk_id"]}"'
                )

            w.add_sub_resource("unlock", "Resource", sub_fields)

        unlock_ref = 'SubResource("unlock")' if unlock is not None else "null"
        w.add_field('script = ExtResource("1_ilay")')
        w.add_field_str("layer_id", layer_id)
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_int("base_value", int(entry["base_value"]))
        w.add_field(f"unlock_action = {unlock_ref}")
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        layer_id = tres_field(text, "layer_id") or ""
        if uid:
            ctx.uid_to_id[uid] = layer_id

        display_name = tres_field(text, "display_name") or layer_id
        base_value = int(tres_field(text, "base_value") or 0)

        subs = sub_resources(text)
        ext_res = ext_resources(text)

        unlock: dict | None = None
        unlock_raw = tres_field(text, "unlock_action")
        if unlock_raw and unlock_raw != "null":
            m = re.match(r'SubResource\("([^"]+)"\)', unlock_raw)
            if m:
                fields = subs.get(m.group(1), {})
                unlock = {
                    "difficulty": float(fields.get("difficulty", "1.0")),
                }

                skill_raw = fields.get("required_skill", "null")
                sm = re.match(r'ExtResource\("([^"]+)"\)', skill_raw)
                if sm:
                    skill_uid = ext_res.get(sm.group(1), {}).get("uid", "")
                    skill_id = ctx.uid_to_id.get(skill_uid, "")
                    if skill_id:
                        unlock["required_skill"] = skill_id
                        required_level = int(fields.get("required_level", "0"))
                        if required_level:
                            unlock["required_level"] = required_level

                required_condition = float(
                    fields.get("required_condition", "0.0")
                )
                if required_condition:
                    unlock["required_condition"] = required_condition

                required_category_rank = int(
                    fields.get("required_category_rank", "0")
                )
                if required_category_rank:
                    unlock["required_category_rank"] = required_category_rank

                required_perk_id = fields.get("required_perk_id", "").strip('"')
                if required_perk_id:
                    unlock["required_perk_id"] = required_perk_id

        return {
            "layer_id": layer_id,
            "display_name": display_name,
            "base_value": base_value,
            "unlock_action": unlock,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_skill_ids: set[str] = {
            s["skill_id"] for s in all_data.get("skills", []) if s.get("skill_id")
        }

        for layer in entries:
            lid = layer.get("layer_id", "?")
            unlock = layer.get("unlock_action")

            if unlock is None:
                continue

            if "difficulty" in unlock:
                diff = unlock.get("difficulty")
                if not isinstance(diff, (int, float)) or float(diff) <= 0.0:
                    errors.append(
                        f"layer '{lid}': unlock_action.difficulty must be a"
                        f" positive float, got {diff!r}"
                    )

            sid = unlock.get("required_skill")
            if sid and known_skill_ids and sid not in known_skill_ids:
                errors.append(f"layer '{lid}': unknown required_skill '{sid}'")

        return errors


SPEC = IdentityLayerSpec()
