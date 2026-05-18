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
from tres_lib.entities.clue_data import SCRIPT_PATHS as CLUE_DATA_SCRIPT_PATHS


def _gd_string(value: str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


@dataclass
class IdentityLayerSpec:
    yaml_key: str = "identity_layers"
    tres_subdir: str = "identity_layers"
    uid_prefix: str = "identity_layer"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "identity_layer": "res://data/definitions/identity_layer.gd",
            "layer_unlock_action": "res://data/definitions/layer_unlock_action.gd",
            **CLUE_DATA_SCRIPT_PATHS,
        }
    )

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
        clues = entry.get("clues", []) or []

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

            perk_tag: str | None = None
            pid = unlock.get("required_perk")
            if pid:
                puid = ctx.uid_cache.get(pid)
                if puid:
                    w.add_ext_resource(
                        "4_perk",
                        "Resource",
                        f"res://data/tres/perks/{pid}.tres",
                        puid,
                    )
                    perk_tag = "4_perk"

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
            if perk_tag:
                sub_fields.append(f'required_perk = ExtResource("{perk_tag}")')

            w.add_sub_resource("unlock", "Resource", sub_fields)

        clue_sub_ids: list[str] = []
        if clues:
            w.add_ext_resource(
                "5_clue",
                "Script",
                "res://data/definitions/clue_data.gd",
                ctx.script_uids["clue_data"],
            )

            for i, clue in enumerate(clues):
                sub_id = f"clue_{i}"
                skill_tag: str | None = None
                sid = clue.get("required_skill")
                if sid:
                    suid = ctx.uid_cache.get(sid)
                    if suid:
                        skill_tag = f"clue_{i}_skill"
                        w.add_ext_resource(
                            skill_tag,
                            "Resource",
                            f"res://data/tres/skills/{sid}.tres",
                            suid,
                        )

                perk_tag: str | None = None
                pid = clue.get("required_perk")
                if pid:
                    puid = ctx.uid_cache.get(pid)
                    if puid:
                        perk_tag = f"clue_{i}_perk"
                        w.add_ext_resource(
                            perk_tag,
                            "Resource",
                            f"res://data/tres/perks/{pid}.tres",
                            puid,
                        )

                clue_fields = [
                    'script = ExtResource("5_clue")',
                    f'clue_id = {_gd_string(clue.get("clue_id", ""))}',
                    f'known_text = {_gd_string(clue.get("known_text", ""))}',
                ]
                unknown_hint_text = clue.get("unknown_hint_text", "")
                if unknown_hint_text:
                    clue_fields.append(
                        f"unknown_hint_text = {_gd_string(unknown_hint_text)}"
                    )
                ap_cost_penalty = int(clue.get("ap_cost_penalty", 0))
                if ap_cost_penalty:
                    clue_fields.append(f"ap_cost_penalty = {ap_cost_penalty}")
                if skill_tag:
                    clue_fields.append(f'required_skill = ExtResource("{skill_tag}")')
                    clue_fields.append(
                        f'required_level = {int(clue.get("required_level", 0))}'
                    )
                required_category_rank = int(clue.get("required_category_rank", 0))
                if required_category_rank:
                    clue_fields.append(
                        f"required_category_rank = {required_category_rank}"
                    )
                if perk_tag:
                    clue_fields.append(f'required_perk = ExtResource("{perk_tag}")')

                w.add_sub_resource(sub_id, "Resource", clue_fields)
                clue_sub_ids.append(sub_id)

        unlock_ref = 'SubResource("unlock")' if unlock is not None else "null"
        w.add_field('script = ExtResource("1_ilay")')
        w.add_field_str("layer_id", layer_id)
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_int("base_value", int(entry["base_value"]))
        w.add_field(f"unlock_action = {unlock_ref}")
        w.add_field_sub_ref_array("clues", clue_sub_ids)
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

                required_condition = float(fields.get("required_condition", "0.0"))
                if required_condition:
                    unlock["required_condition"] = required_condition

                required_category_rank = int(fields.get("required_category_rank", "0"))
                if required_category_rank:
                    unlock["required_category_rank"] = required_category_rank

                perk_raw = fields.get("required_perk", "null")
                pm = re.match(r'ExtResource\("([^"]+)"\)', perk_raw)
                if pm:
                    perk_uid = ext_res.get(pm.group(1), {}).get("uid", "")
                    perk_id = ctx.uid_to_id.get(perk_uid, "")
                    if perk_id:
                        unlock["required_perk"] = perk_id

        clues: list[dict] = []
        clues_raw = tres_field(text, "clues") or "[]"
        for cm in re.finditer(r'SubResource\("([^"]+)"\)', clues_raw):
            fields = subs.get(cm.group(1), {})
            clue = {
                "clue_id": fields.get("clue_id", ""),
                "known_text": fields.get("known_text", ""),
            }
            unknown_hint_text = fields.get("unknown_hint_text", "")
            if unknown_hint_text:
                clue["unknown_hint_text"] = unknown_hint_text

            ap_cost_penalty = int(fields.get("ap_cost_penalty", "0"))
            if ap_cost_penalty:
                clue["ap_cost_penalty"] = ap_cost_penalty

            skill_raw = fields.get("required_skill", "null")
            sm = re.match(r'ExtResource\("([^"]+)"\)', skill_raw)
            if sm:
                skill_uid = ext_res.get(sm.group(1), {}).get("uid", "")
                skill_id = ctx.uid_to_id.get(skill_uid, "")
                if skill_id:
                    clue["required_skill"] = skill_id
                    required_level = int(fields.get("required_level", "0"))
                    if required_level:
                        clue["required_level"] = required_level

            required_category_rank = int(fields.get("required_category_rank", "0"))
            if required_category_rank:
                clue["required_category_rank"] = required_category_rank

            perk_raw = fields.get("required_perk", "null")
            pm = re.match(r'ExtResource\("([^"]+)"\)', perk_raw)
            if pm:
                perk_uid = ext_res.get(pm.group(1), {}).get("uid", "")
                perk_id = ctx.uid_to_id.get(perk_uid, "")
                if perk_id:
                    clue["required_perk"] = perk_id

            clues.append(clue)

        return {
            "layer_id": layer_id,
            "display_name": display_name,
            "base_value": base_value,
            "unlock_action": unlock,
            "clues": clues,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_skill_ids: set[str] = {
            s["skill_id"] for s in all_data.get("skills", []) if s.get("skill_id")
        }
        known_perk_ids: set[str] = {
            p["perk_id"] for p in all_data.get("perks", []) if p.get("perk_id")
        }
        seen_clue_ids: set[str] = set()

        for layer in entries:
            lid = layer.get("layer_id", "?")
            unlock = layer.get("unlock_action")

            clues = layer.get("clues", []) or []
            if not isinstance(clues, list):
                errors.append(f"layer '{lid}': clues must be a list")
                clues = []

            for clue in clues:
                clue_id = clue.get("clue_id", "") if isinstance(clue, dict) else ""
                if not clue_id:
                    errors.append(f"layer '{lid}': clue_id is required")
                    continue
                if clue_id in seen_clue_ids:
                    errors.append(f"Duplicate clue_id: '{clue_id}'")
                seen_clue_ids.add(clue_id)

                known_text = clue.get("known_text", "")
                if not isinstance(known_text, str) or not known_text.strip():
                    errors.append(f"clue '{clue_id}': known_text is required")

                ap_cost_penalty = clue.get("ap_cost_penalty", 0)
                if type(ap_cost_penalty) is not int or ap_cost_penalty < 0:
                    errors.append(
                        f"clue '{clue_id}': ap_cost_penalty must be a non-negative int"
                    )

                sid = clue.get("required_skill")
                if sid and known_skill_ids and sid not in known_skill_ids:
                    errors.append(f"clue '{clue_id}': unknown required_skill '{sid}'")

                pid = clue.get("required_perk")
                if pid and known_perk_ids and pid not in known_perk_ids:
                    errors.append(f"clue '{clue_id}': unknown required_perk '{pid}'")

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

            pid = unlock.get("required_perk")
            if pid and known_perk_ids and pid not in known_perk_ids:
                errors.append(f"layer '{lid}': unknown required_perk '{pid}'")

        return errors


SPEC = IdentityLayerSpec()
