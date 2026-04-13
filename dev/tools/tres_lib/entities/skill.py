"""EntitySpec for skills."""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter, format_dict
from tres_lib.tres_format import (
    header_uid,
    field as tres_field,
    sub_resources,
    parse_godot_dict,
)


@dataclass
class SkillSpec:
    yaml_key: str = "skills"
    tres_subdir: str = "skills"
    uid_prefix: str = "skill"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "skill_data": "res://data/definitions/skill_data.gd",
        "skill_level_data": "res://data/definitions/skill_level_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["skill_id"]

    def build_label(self, entry: dict) -> str:
        return f"skill ({len(entry.get('levels', []))} levels)"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        sid = entry["skill_id"]
        uid = deterministic_uid(self.uid_prefix, sid)
        ctx.uid_cache[sid] = uid

        w = TresWriter("Resource", "SkillData", uid)
        w.add_ext_resource(
            "1_skill",
            "Script",
            "res://data/definitions/skill_data.gd",
            ctx.script_uids["skill_data"],
        )
        w.add_ext_resource(
            "2_lvl",
            "Script",
            "res://data/definitions/skill_level_data.gd",
            ctx.script_uids["skill_level_data"],
        )

        levels = entry["levels"]
        sub_ids: list[str] = []
        for i, level in enumerate(levels):
            ranks = level.get("required_super_category_ranks", {}) or {}
            sub_id = f"lvl_{i}"
            w.add_sub_resource(sub_id, "Resource", [
                'script = ExtResource("2_lvl")',
                f'cash_cost = {int(level["cash_cost"])}',
                f'required_mastery_rank = {int(level.get("required_mastery_rank", 0))}',
                f"required_super_category_ranks = {format_dict(ranks)}",
            ])
            sub_ids.append(sub_id)

        w.add_field('script = ExtResource("1_skill")')
        w.add_field_str("skill_id", sid)
        w.add_field_str("display_name", entry["display_name"])
        w.add_field_sub_ref_array("levels", sub_ids)
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        skill_id = tres_field(text, "skill_id") or ""
        if uid:
            ctx.uid_to_id[uid] = skill_id

        display_name = tres_field(text, "display_name") or skill_id
        subs = sub_resources(text)

        level_ids = [sid for sid in subs if sid.startswith("lvl_")]
        level_ids.sort(
            key=lambda s: int(s.split("_", 1)[1]) if s.split("_", 1)[1].isdigit() else 0
        )

        levels: list[dict] = []
        for lid in level_ids:
            fields = subs[lid]
            levels.append({
                "cash_cost": int(fields.get("cash_cost", "0")),
                "required_mastery_rank": int(
                    fields.get("required_mastery_rank", "0")
                ),
                "required_super_category_ranks": parse_godot_dict(
                    fields.get("required_super_category_ranks", "{}")
                ),
            })

        return {
            "skill_id": skill_id,
            "display_name": display_name,
            "levels": levels,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_skill_ids: set[str] = set()

        for skill in entries:
            sid = skill.get("skill_id", "")
            if not sid:
                errors.append("Skill missing skill_id")
                continue
            if sid in seen_skill_ids:
                errors.append(f"Duplicate skill_id: '{sid}'")
            seen_skill_ids.add(sid)

            if not skill.get("display_name"):
                errors.append(f"Skill '{sid}': missing display_name")

            levels = skill.get("levels", [])
            if not levels:
                errors.append(f"Skill '{sid}': no levels defined")
                continue

            for i, level in enumerate(levels):
                if "cash_cost" not in level:
                    errors.append(f"Skill '{sid}' level {i}: missing cash_cost")
                elif not isinstance(level["cash_cost"], int) or level["cash_cost"] < 0:
                    errors.append(
                        f"Skill '{sid}' level {i}: cash_cost must be a non-negative integer"
                    )

                ranks = level.get("required_super_category_ranks", {})
                if ranks is not None and not isinstance(ranks, dict):
                    errors.append(
                        f"Skill '{sid}' level {i}: required_super_category_ranks must be a dict"
                    )

        return errors


SPEC = SkillSpec()
