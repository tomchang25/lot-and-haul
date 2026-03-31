"""
export_tres.py
Write .tres files from lot_haul.db.

Preserves existing Godot UIDs (read from DB, which were seeded from .tres).
Generates a new uid://... only for brand-new rows that have no uid yet.

Usage:
    python export_tres.py --godot-root /path/to/godot/project
    python export_tres.py --godot-root /path/to/godot/project --dry-run
"""

import argparse
import json
import random
import sqlite3
import string
from pathlib import Path


# ── UID helpers ───────────────────────────────────────────────────────────────

_UID_CHARS = string.ascii_lowercase + string.digits

# Stable script UIDs — these never change; sourced from the .gd files.
_ITEM_DATA_SCRIPT_UID = "uid://bhqs42afjqbgi"
_VEILED_TYPE_SCRIPT_UID = "uid://bku4smrdbihvx"


def _new_uid() -> str:
    """Generate a plausible Godot-style uid (uid://xxxxxxxxxxxx)."""
    suffix = "".join(random.choices(_UID_CHARS, k=12))
    return f"uid://{suffix}"


# ── VeiledType writer ─────────────────────────────────────────────────────────

_VT_TEMPLATE = """\
[gd_resource type="Resource" script_class="VeiledType" format=3 uid="{uid}"]

[ext_resource type="Script" uid="{script_uid}" path="res://data/_definitions/veiled_type.gd" id="1_vtdef"]

[resource]
script = ExtResource("1_vtdef")
type_id = "{type_id}"
display_label = "{display_label}"
base_veiled_price = {base_veiled_price}
"""


def export_veiled_types(conn: sqlite3.Connection, vt_dir: Path, dry_run: bool) -> None:
    cur = conn.cursor()
    rows = cur.execute(
        """
        SELECT type_id, display_label, base_veiled_price, uid
        FROM veiled_types
        ORDER BY type_id
    """
    ).fetchall()

    for type_id, label, price, uid in rows:
        uid = uid or _new_uid()

        content = _VT_TEMPLATE.format(
            uid=uid,
            script_uid=_VEILED_TYPE_SCRIPT_UID,
            type_id=type_id,
            display_label=label,
            base_veiled_price=price,
        )

        out = vt_dir / f"{type_id}.tres"
        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            cur.execute(
                "UPDATE veiled_types SET uid = ? WHERE type_id = ?",
                (uid, type_id),
            )
            print(f"  veiled_type → {out.name}")

    if not dry_run:
        conn.commit()


# ── ItemData writer ───────────────────────────────────────────────────────────


def _build_item_tres(row: dict, vt_rows: list[dict]) -> str:
    uid = row["uid"] or _new_uid()
    clues = json.loads(row["clues"])

    lines = [
        f'[gd_resource type="Resource" script_class="ItemData" format=3 uid="{uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_ITEM_DATA_SCRIPT_UID}" path="res://data/_definitions/item_data.gd" id="1_jyqit"]',
        f'[ext_resource type="Script" uid="{_VEILED_TYPE_SCRIPT_UID}" path="res://data/_definitions/veiled_type.gd" id="2_vtscript"]',
    ]

    vt_ext_ids = []
    for i, vt in enumerate(vt_rows):
        tag = f"{i + 2}_vt"
        lines.append(
            f'[ext_resource type="Resource" uid="{vt["uid"]}" '
            f'path="res://data/veiled_types/{vt["type_id"]}.tres" id="{tag}"]'
        )
        vt_ext_ids.append(tag)

    clues_str = ", ".join(f'"{c}"' for c in clues)
    vt_refs = ", ".join(f'ExtResource("{t}")' for t in vt_ext_ids)

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_jyqit")',
        f'item_name = "{row["item_name"]}"',
        f'true_value = {row["true_value"]}',
        f'weight = {float(row["weight"])}',
        f'grid_size = {row["grid_size"]}',
        f'super_category = "{row["super_category"]}"',
        f'category = "{row["category"]}"',
        f"clues = Array[String]([{clues_str}])",
        f'veiled_types = Array[ExtResource("2_vtscript")]([{vt_refs}])',
        "",
    ]

    return "\n".join(lines)


def export_items(conn: sqlite3.Connection, item_dir: Path, dry_run: bool) -> None:
    cur = conn.cursor()
    items = cur.execute(
        """
        SELECT id, item_name, true_value, weight, grid_size,
               super_category, category, clues, uid
        FROM items
        ORDER BY id
    """
    ).fetchall()

    col_names = [
        "id",
        "item_name",
        "true_value",
        "weight",
        "grid_size",
        "super_category",
        "category",
        "clues",
        "uid",
    ]

    for raw in items:
        row = dict(zip(col_names, raw))
        item_id = row["id"]

        vt_rows_raw = cur.execute(
            """
            SELECT vt.type_id, vt.uid
            FROM item_veiled_types ivt
            JOIN veiled_types vt ON vt.type_id = ivt.type_id
            WHERE ivt.item_id = ?
            ORDER BY ivt.sort_order
        """,
            (item_id,),
        ).fetchall()
        vt_rows = [{"type_id": r[0], "uid": r[1]} for r in vt_rows_raw]

        content = _build_item_tres(row, vt_rows)
        out = item_dir / f"{item_id}.tres"

        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            print(f"  item → {out.name}")


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = Path(args.godot_root)
    vt_dir = root / "data" / "veiled_types"
    item_dir = root / "data" / "items"
    db_path = root / "data" / "_db" / "lot_haul.db"

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    print("Exporting veiled_types...")
    export_veiled_types(conn, vt_dir, args.dry_run)

    print("Exporting items...")
    export_items(conn, item_dir, args.dry_run)

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
