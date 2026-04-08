"""
tres_to_db.py
Seed lot_haul.db from existing .tres files in the Godot project.

Reads: data/skills/, data/categories/, data/identity_layers/, data/items/
All inserts use UPSERT so re-running is safe.

Usage:
    python tres_to_db.py --godot-root /path/to/godot/project
"""

import argparse
import re
import sqlite3
import sys
from pathlib import Path


# ── .tres helpers ─────────────────────────────────────────────────────────────


def _header_uid(text: str) -> str | None:
    m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
    return m.group(1) if m else None


def _ext_resources(text: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for m in re.finditer(r"\[ext_resource([^\]]+)\]", text):
        a = m.group(1)

        def _a(k: str) -> str:
            r = re.search(rf'(?<![a-z]){k}="([^"]+)"', a)
            return r.group(1) if r else ""

        tag = _a("id")
        if tag:
            out[tag] = {"uid": _a("uid"), "path": _a("path"), "type": _a("type")}
    return out


def _field(text: str, key: str) -> str | None:
    m = re.search(rf'^{re.escape(key)}\s*=\s*"?([^"\n]+)"?', text, re.MULTILINE)
    return m.group(1).strip() if m else None


def _sub_resources(text: str) -> dict[str, dict[str, str]]:
    subs: dict[str, dict[str, str]] = {}
    for bm in re.finditer(
        r'\[sub_resource[^\]]*id="([^"]+)"\](.*?)(?=\n\[|\Z)', text, re.DOTALL
    ):
        fields: dict[str, str] = {}
        for line in bm.group(2).splitlines():
            m = re.match(r"(\w+)\s*=\s*(.+)", line.strip())
            if m:
                fields[m.group(1)] = m.group(2).strip().strip('"')
        subs[bm.group(1)] = fields
    return subs


# ── Seeders ───────────────────────────────────────────────────────────────────


def seed_skills(conn: sqlite3.Connection, skills_dir: Path) -> dict[str, str]:
    """Returns {uid: skill_id}."""
    cur = conn.cursor()
    uid_map: dict[str, str] = {}
    for f in sorted(skills_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        skill_id = _field(text, "skill_id") or f.stem
        name = _field(text, "display_name") or skill_id
        max_lv = int(_field(text, "max_level") or 5)
        cur.execute(
            """
            INSERT INTO skills (skill_id, display_name, max_level, uid)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(skill_id) DO UPDATE SET
                display_name = excluded.display_name,
                max_level    = excluded.max_level,
                uid          = excluded.uid
            """,
            (skill_id, name, max_lv, uid),
        )
        if uid:
            uid_map[uid] = skill_id
        print(f"  skill: {skill_id}")
    conn.commit()
    return uid_map


def seed_categories(conn: sqlite3.Connection, categories_dir: Path) -> dict[str, str]:
    """Returns {uid: category_id}."""
    cur = conn.cursor()
    uid_map: dict[str, str] = {}
    for f in sorted(categories_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        category_id = _field(text, "category_id") or f.stem
        super_cat = _field(text, "super_category") or ""
        name = _field(text, "display_name") or category_id
        weight = float(_field(text, "weight") or 0.0)
        grid_size = int(_field(text, "grid_size") or 1)
        cur.execute(
            """
            INSERT INTO categories
                (category_id, super_category, display_name, weight, grid_size, uid)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(category_id) DO UPDATE SET
                super_category = excluded.super_category,
                display_name   = excluded.display_name,
                weight         = excluded.weight,
                grid_size      = excluded.grid_size,
                uid            = excluded.uid
            """,
            (category_id, super_cat, name, weight, grid_size, uid),
        )
        if uid:
            uid_map[uid] = category_id
        print(f"  category: {category_id}")
    conn.commit()
    return uid_map


def seed_identity_layers(
    conn: sqlite3.Connection,
    layers_dir: Path,
    skill_uid_map: dict[str, str],
) -> None:
    cur = conn.cursor()
    for f in sorted(layers_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        uid = _header_uid(text)
        subs = _sub_resources(text)
        ext_res = _ext_resources(text)
        layer_id = _field(text, "layer_id") or f.stem
        name = _field(text, "display_name") or ""
        value = int(_field(text, "base_value") or 0)

        cur.execute(
            """
            INSERT INTO identity_layers (layer_id, display_name, base_value, uid)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(layer_id) DO UPDATE SET
                display_name = excluded.display_name,
                base_value   = excluded.base_value,
                uid          = excluded.uid
            """,
            (layer_id, name, value, uid),
        )

        cur.execute("DELETE FROM layer_unlock_actions WHERE layer_id = ?", (layer_id,))

        unlock_raw = _field(text, "unlock_action")
        unlock_fields: dict[str, str] | None = None

        if unlock_raw and unlock_raw != "null":
            um = re.match(r'SubResource\("([^"]+)"\)', unlock_raw)
            if um:
                unlock_fields = subs.get(um.group(1))

        if unlock_fields:
            skill_id: str | None = None
            skill_raw = unlock_fields.get("required_skill", "null")
            sm = re.match(r'ExtResource\("([^"]+)"\)', skill_raw)
            if sm:
                skill_uid_val = ext_res.get(sm.group(1), {}).get("uid")
                skill_id = skill_uid_map.get(skill_uid_val or "")

            cur.execute(
                """
                INSERT INTO layer_unlock_actions
                    (layer_id, context, unlock_days, skill_id,
                     required_level, required_condition)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    layer_id,
                    int(unlock_fields.get("context", 1)),
                    int(unlock_fields.get("unlock_days", 0)),
                    skill_id,
                    int(unlock_fields.get("required_level", 0)),
                    float(unlock_fields.get("required_condition", 0.0)),
                ),
            )

        print(f"  layer: {layer_id}")
    conn.commit()


def seed_items(
    conn: sqlite3.Connection,
    items_dir: Path,
    category_uid_map: dict[str, str],
) -> None:
    cur = conn.cursor()
    for f in sorted(items_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        item_id = _field(text, "item_id") or f.stem
        uid = _header_uid(text)
        ext_res = _ext_resources(text)
        rarity = int(_field(text, "rarity") or 0)

        category_id: str | None = None
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid")
            category_id = category_uid_map.get(cat_uid or "")

        cur.execute(
            """
            INSERT INTO items (item_id, category_id, rarity, uid)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(item_id) DO UPDATE SET
                category_id = excluded.category_id,
                rarity      = excluded.rarity,
                uid         = excluded.uid
            """,
            (item_id, category_id, rarity, uid),
        )

        il_m = re.search(r"identity_layers\s*=\s*\[([^\]]*)\]", text)
        if il_m:
            cur.execute(
                "DELETE FROM item_identity_layers WHERE item_id = ?", (item_id,)
            )
            for order, tag_m in enumerate(
                re.finditer(r'ExtResource\("([^"]+)"\)', il_m.group(1))
            ):
                layer_uid_val = ext_res.get(tag_m.group(1), {}).get("uid")
                if layer_uid_val:
                    row = cur.execute(
                        "SELECT layer_id FROM identity_layers WHERE uid = ?",
                        (layer_uid_val,),
                    ).fetchone()
                    if row:
                        cur.execute(
                            """
                            INSERT OR REPLACE INTO item_identity_layers
                                (item_id, layer_id, sort_order)
                            VALUES (?, ?, ?)
                            """,
                            (item_id, row[0], order),
                        )

        print(f"  item: {item_id}")
    conn.commit()


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    args = parser.parse_args()

    root = Path(args.godot_root)
    db_path = root / "data" / "_db" / "lot_haul.db"

    if not db_path.exists():
        sys.exit(f"DB not found: {db_path}\nRun init.py first.")

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    print("Seeding skills...")
    skill_uid_map = seed_skills(conn, root / "data" / "skills")

    print("Seeding categories...")
    category_uid_map = seed_categories(conn, root / "data" / "categories")

    print("Seeding identity_layers...")
    seed_identity_layers(conn, root / "data" / "identity_layers", skill_uid_map)

    print("Seeding items...")
    seed_items(conn, root / "data" / "items", category_uid_map)

    conn.close()
    print(f"\nDone → {db_path}")


if __name__ == "__main__":
    main()
