"""
yaml_to_skill_tres.py
Write SkillData .tres files from a YAML file.

Preserves existing Godot UIDs. Generates new uid://... only for new skills.
Also upserts skill_id / display_name into lot_haul.db so layer_unlock_actions
foreign keys remain valid.

Script UIDs for SkillData and SkillLevelData are auto-discovered from existing
.tres files in data/tres/skills/. If no files exist yet, pass them explicitly:

    --skill-data-uid uid://...
    --skill-level-data-uid uid://...

Usage:
    python yaml_to_skill_tres.py --godot-root /path/to/godot/project
    python yaml_to_skill_tres.py --godot-root /path/to/godot/project --dry-run
    python yaml_to_skill_tres.py --godot-root /path/to/godot/project --yaml data/yaml/skills.yaml
"""

import argparse
import random
import re
import sqlite3
import string
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── UID helpers ───────────────────────────────────────────────────────────────

_UID_CHARS = string.ascii_lowercase + string.digits


def _new_uid() -> str:
    return "uid://" + "".join(random.choices(_UID_CHARS, k=12))


# ── Auto-discover script UIDs from existing .tres ─────────────────────────────


def _discover_script_uids(
    skills_dir: Path,
) -> tuple[str | None, str | None]:
    """Scan existing skill .tres files to find SkillData and SkillLevelData
    script UIDs. Returns (skill_data_uid, skill_level_data_uid)."""
    skill_data_uid: str | None = None
    skill_level_data_uid: str | None = None

    for f in skills_dir.glob("*.tres"):
        text = f.read_text(encoding="utf-8")
        for m in re.finditer(
            r'\[ext_resource[^\]]*uid="([^"]+)"[^\]]*path="([^"]+)"[^\]]*\]',
            text,
        ):
            uid, path = m.group(1), m.group(2)
            if path.endswith("skill_data.gd"):
                skill_data_uid = uid
            elif path.endswith("skill_level_data.gd"):
                skill_level_data_uid = uid

        if skill_data_uid and skill_level_data_uid:
            break

    return skill_data_uid, skill_level_data_uid


# ── Read existing resource UIDs ───────────────────────────────────────────────


def _read_existing_uids(skills_dir: Path) -> dict[str, str]:
    """Returns {skill_id: resource_uid} from existing .tres files."""
    uid_map: dict[str, str] = {}
    for f in skills_dir.glob("*.tres"):
        text = f.read_text(encoding="utf-8")
        skill_id = f.stem
        m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
        if m:
            uid_map[skill_id] = m.group(1)
    return uid_map


# ── .tres builder ─────────────────────────────────────────────────────────────


def _format_dict(d: dict) -> str:
    """Format a Python dict as a Godot Dictionary literal."""
    if not d:
        return "{}"
    pairs = ", ".join(f'"{k}": {v}' for k, v in sorted(d.items()))
    return "{ " + pairs + " }"


def _build_skill_tres(
    skill_id: str,
    resource_uid: str,
    display_name: str,
    levels: list[dict],
    skill_data_script_uid: str,
    skill_level_data_script_uid: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="SkillData" format=3 uid="{resource_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{skill_data_script_uid}" '
        f'path="res://data/definitions/skill_data.gd" id="1_skill"]',
        f'[ext_resource type="Script" uid="{skill_level_data_script_uid}" '
        f'path="res://data/definitions/skill_level_data.gd" id="2_lvl"]',
    ]

    # Sub-resources for each level
    for i, level in enumerate(levels):
        ranks = level.get("required_super_category_ranks", {})
        lines += [
            "",
            f'[sub_resource type="Resource" id="lvl_{i}"]',
            'script = ExtResource("2_lvl")',
            f'cash_cost = {level["cash_cost"]}',
            f'required_mastery_rank = {level.get("required_mastery_rank", 0)}',
            f"required_super_category_ranks = {_format_dict(ranks)}",
        ]

    level_refs = ", ".join(f'SubResource("lvl_{i}")' for i in range(len(levels)))

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_skill")',
        f'skill_id = "{skill_id}"',
        f'display_name = "{display_name}"',
        f"levels = [{level_refs}]",
        "",
    ]
    return "\n".join(lines)


# ── Validation ────────────────────────────────────────────────────────────────


def _validate(data: dict) -> list[str]:
    errors: list[str] = []
    skills = data.get("skills", [])
    if not skills:
        errors.append("No skills defined")
        return errors

    seen_ids: set[str] = set()
    for skill in skills:
        sid = skill.get("skill_id", "")
        if not sid:
            errors.append("Skill missing skill_id")
            continue
        if sid in seen_ids:
            errors.append(f"Duplicate skill_id: '{sid}'")
        seen_ids.add(sid)

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
                errors.append(f"Skill '{sid}' level {i}: cash_cost must be a non-negative integer")

            ranks = level.get("required_super_category_ranks", {})
            if not isinstance(ranks, dict):
                errors.append(f"Skill '{sid}' level {i}: required_super_category_ranks must be a dict")

    return errors


# ── DB upsert ─────────────────────────────────────────────────────────────────


def _upsert_db(
    db_path: Path, skills: list[dict], dry_run: bool
) -> None:
    """Upsert skill_id + display_name into the skills table for FK integrity."""
    if not db_path.exists():
        print(f"  DB not found at {db_path} — skipping DB upsert")
        return

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    cur = conn.cursor()

    for skill in skills:
        sid = skill["skill_id"]
        name = skill["display_name"]
        if dry_run:
            print(f"  [dry] db upsert: {sid}")
        else:
            cur.execute(
                """
                INSERT INTO skills (skill_id, display_name)
                VALUES (?, ?)
                ON CONFLICT(skill_id) DO UPDATE SET
                    display_name = excluded.display_name
                """,
                (sid, name),
            )
            print(f"  db upsert: {sid}")

    if not dry_run:
        conn.commit()
    conn.close()


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Write SkillData .tres files from a YAML file."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--yaml",
        default=None,
        help="Path to skills YAML file (default: <godot-root>/data/yaml/skills.yaml)",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--skill-data-uid",
        default=None,
        help="Script UID for skill_data.gd (auto-discovered if omitted)",
    )
    parser.add_argument(
        "--skill-level-data-uid",
        default=None,
        help="Script UID for skill_level_data.gd (auto-discovered if omitted)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    skills_dir = root / "data" / "tres" / "skills"
    skills_dir.mkdir(parents=True, exist_ok=True)

    # ── Resolve YAML path ─────────────────────────────────────────────────────
    yaml_path = Path(args.yaml) if args.yaml else root / "data" / "yaml" / "skills.yaml"
    if not yaml_path.exists():
        sys.exit(f"YAML file not found: {yaml_path}")

    data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
    if not data:
        sys.exit("YAML file is empty")

    # ── Validate ──────────────────────────────────────────────────────────────
    print("Validating...")
    errors = _validate(data)
    if errors:
        print(f"  {len(errors)} error(s) found — aborting:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")

    # ── Resolve script UIDs ───────────────────────────────────────────────────
    discovered_sd, discovered_sld = _discover_script_uids(skills_dir)
    skill_data_uid = args.skill_data_uid or discovered_sd
    skill_level_data_uid = args.skill_level_data_uid or discovered_sld

    if not skill_data_uid or not skill_level_data_uid:
        msg = "Cannot determine script UIDs.\n"
        if not skill_data_uid:
            msg += "  Missing: skill_data.gd UID (pass --skill-data-uid)\n"
        if not skill_level_data_uid:
            msg += "  Missing: skill_level_data.gd UID (pass --skill-level-data-uid)\n"
        msg += (
            "\nTip: create one SkillData .tres in the Godot editor first, then re-run.\n"
            "The script will auto-discover UIDs from existing files."
        )
        sys.exit(msg)

    print(f"  SkillData script UID:      {skill_data_uid}")
    print(f"  SkillLevelData script UID: {skill_level_data_uid}")

    # ── Read existing resource UIDs ───────────────────────────────────────────
    existing_uids = _read_existing_uids(skills_dir)

    # ── Write .tres files ─────────────────────────────────────────────────────
    skills = data["skills"]
    print("Exporting skills...")
    for skill in skills:
        sid = skill["skill_id"]
        resource_uid = existing_uids.get(sid, _new_uid())
        content = _build_skill_tres(
            sid,
            resource_uid,
            skill["display_name"],
            skill["levels"],
            skill_data_uid,
            skill_level_data_uid,
        )
        out = skills_dir / f"{sid}.tres"
        if args.dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            print(f"  skill → {out.name}  ({len(skill['levels'])} levels)")

    # ── DB upsert ─────────────────────────────────────────────────────────────
    db_path = root / "data" / "db" / "lot_haul.db"
    print("Upserting into DB...")
    _upsert_db(db_path, skills, args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()
