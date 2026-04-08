"""
db_to_tres.py
Write CategoryData, IdentityLayer, and ItemData .tres files from lot_haul.db.

Preserves existing Godot UIDs. Generates new uid://... only for rows without one.

Usage:
    python db_to_tres.py --godot-root /path/to/godot/project
    python db_to_tres.py --godot-root /path/to/godot/project --dry-run
"""

import argparse
import random
import sqlite3
import string
import sys
from pathlib import Path


# ── UID helpers ───────────────────────────────────────────────────────────────

_UID_CHARS = string.ascii_lowercase + string.digits

_ITEM_DATA_SCRIPT_UID = "uid://bhqs42afjqbgi"
_IDENTITY_LAYER_SCRIPT_UID = "uid://btknl1cvjqdvh"
_LAYER_UNLOCK_SCRIPT_UID = "uid://c23t4blqmaaj4"
_CATEGORY_DATA_SCRIPT_UID = "uid://c7fq6wupmgchg"
_SUPER_CATEGORY_DATA_SCRIPT_UID = "uid://d4gdoi2l561vy"


def _new_uid() -> str:
    return "uid://" + "".join(random.choices(_UID_CHARS, k=12))


# ── .tres builders ────────────────────────────────────────────────────────────


def _build_layer_tres(
    layer_id: str,
    layer_uid: str,
    display_name: str,
    base_value: int,
    unlock: dict | None,
    skill_uid_map: dict[str, str],
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="IdentityLayer" format=3 uid="{layer_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_IDENTITY_LAYER_SCRIPT_UID}" '
        f'path="res://data/_definitions/identity_layer.gd" id="1_ilay"]',
    ]

    if unlock is not None:
        lines.append(
            f'[ext_resource type="Script" uid="{_LAYER_UNLOCK_SCRIPT_UID}" '
            f'path="res://data/_definitions/layer_unlock_action.gd" id="2_unlock"]'
        )

        skill_tag: str | None = None
        if unlock.get("skill_id"):
            sid = unlock["skill_id"]
            suid = skill_uid_map.get(sid)
            if suid:
                lines.append(
                    f'[ext_resource type="Resource" uid="{suid}" '
                    f'path="res://data/skills/{sid}.tres" id="3_skill"]'
                )
                skill_tag = "3_skill"

        skill_ref = f'ExtResource("{skill_tag}")' if skill_tag else "null"
        lines += [
            "",
            '[sub_resource type="Resource" id="unlock"]',
            'script = ExtResource("2_unlock")',
            f'context = {unlock["context"]}',
            f'unlock_days = {unlock["unlock_days"]}',
        ]
        if skill_tag:
            lines += [
                f"required_skill = {skill_ref}",
                f'required_level = {unlock["required_level"]}',
            ]
        if unlock.get("required_condition", 0.0) != 0.0:
            lines.append(f'required_condition = {float(unlock["required_condition"])}')
        lines.append("")

    unlock_ref = 'SubResource("unlock")' if unlock is not None else "null"
    lines += [
        "[resource]",
        'script = ExtResource("1_ilay")',
        f'layer_id = "{layer_id}"',
        f'display_name = "{display_name}"',
        f"base_value = {base_value}",
        f"unlock_action = {unlock_ref}",
        "",
    ]
    return "\n".join(lines)


def _build_super_category_tres(
    super_category_id: str,
    super_category_uid: str,
    display_name: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="SuperCategoryData" format=3 uid="{super_category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_SUPER_CATEGORY_DATA_SCRIPT_UID}" '
        f'path="res://data/_definitions/super_category_data.gd" id="1_superdef"]',
        "",
        "[resource]",
        'script = ExtResource("1_superdef")',
        f'super_category_id = "{super_category_id}"',
        f'display_name = "{display_name}"',
        "",
    ]
    return "\n".join(lines)


def _build_category_tres(
    category_id: str,
    category_uid: str,
    super_category_id: str,
    super_category_uid: str,
    display_name: str,
    weight: float,
    shape_id: str,
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="CategoryData" format=3 uid="{category_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_CATEGORY_DATA_SCRIPT_UID}" '
        f'path="res://data/_definitions/category_data.gd" id="1_catdef"]',
        f'[ext_resource type="Resource" uid="{super_category_uid}" '
        f'path="res://data/super_categories/{super_category_id}.tres" id="2_super"]',
        "",
        "[resource]",
        'script = ExtResource("1_catdef")',
        f'category_id = "{category_id}"',
        'super_category = ExtResource("2_super")',
        f'display_name = "{display_name}"',
        f"weight = {float(weight)}",
        f'shape_id = "{shape_id}"',
        "",
    ]
    return "\n".join(lines)


def _build_item_tres(
    item_id: str,
    item_uid: str,
    category_uid: str | None,
    category_id: str | None,
    rarity: int,
    layers: list[dict],
) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="ItemData" format=3 uid="{item_uid}"]',
        "",
        f'[ext_resource type="Script" uid="{_ITEM_DATA_SCRIPT_UID}" '
        f'path="res://data/_definitions/item_data.gd" id="1_jyqit"]',
    ]

    if category_uid and category_id:
        lines.append(
            f'[ext_resource type="Resource" uid="{category_uid}" '
            f'path="res://data/categories/{category_id}.tres" id="2_cat"]'
        )

    for i, layer in enumerate(layers):
        tag = f"{3 + i}_layer"
        lines.append(
            f'[ext_resource type="Resource" uid="{layer["layer_uid"]}" '
            f'path="res://data/identity_layers/{layer["layer_id"]}.tres" id="{tag}"]'
        )

    cat_ref = 'ExtResource("2_cat")' if (category_uid and category_id) else "null"
    layer_refs = ", ".join(f'ExtResource("{3 + i}_layer")' for i in range(len(layers)))

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_jyqit")',
        f'item_id = "{item_id}"',
        f"category_data = {cat_ref}",
        f"identity_layers = [{layer_refs}]",
        f"rarity = {rarity}",
        "",
    ]
    return "\n".join(lines)


# ── Exporters ─────────────────────────────────────────────────────────────────


def export_super_categories(
    conn: sqlite3.Connection, super_categories_dir: Path, dry_run: bool
) -> dict[str, str]:
    """Export SuperCategoryData .tres files. Returns {super_category_id: uid}."""
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT super_category_id, display_name, uid "
        "FROM super_categories ORDER BY super_category_id"
    ).fetchall()

    uid_map: dict[str, str] = {}
    for super_category_id, display_name, uid in rows:
        uid = uid or _new_uid()
        uid_map[super_category_id] = uid
        content = _build_super_category_tres(super_category_id, uid, display_name)
        out = super_categories_dir / f"{super_category_id}.tres"
        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            cur.execute(
                "UPDATE super_categories SET uid = ? WHERE super_category_id = ?",
                (uid, super_category_id),
            )
            print(f"  super_category → {out.name}")

    if not dry_run:
        conn.commit()

    return uid_map


def export_categories(
    conn: sqlite3.Connection,
    categories_dir: Path,
    super_category_uid_map: dict[str, str],
    dry_run: bool,
) -> None:
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT category_id, super_category, display_name, weight, shape_id, uid "
        "FROM categories ORDER BY category_id"
    ).fetchall()

    for category_id, super_category, display_name, weight, shape_id, uid in rows:
        uid = uid or _new_uid()
        super_category_id = super_category.lower().replace(" ", "_")
        super_category_uid = super_category_uid_map.get(super_category_id, "")
        content = _build_category_tres(
            category_id,
            uid,
            super_category_id,
            super_category_uid,
            display_name,
            weight,
            shape_id,
        )
        out = categories_dir / f"{category_id}.tres"
        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            cur.execute(
                "UPDATE categories SET uid = ? WHERE category_id = ?",
                (uid, category_id),
            )
            print(f"  category → {out.name}")

    if not dry_run:
        conn.commit()


def export_identity_layers(
    conn: sqlite3.Connection,
    layers_dir: Path,
    dry_run: bool,
    skill_uid_map: dict[str, str],
) -> None:
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT layer_id, display_name, base_value, uid FROM identity_layers ORDER BY layer_id"
    ).fetchall()

    for layer_id, display_name, base_value, uid in rows:
        uid = uid or _new_uid()
        unlock_row = cur.execute(
            "SELECT context, unlock_days, skill_id, required_level, required_condition "
            "FROM layer_unlock_actions WHERE layer_id = ?",
            (layer_id,),
        ).fetchone()

        unlock: dict | None = None
        if unlock_row:
            unlock = {
                "context": unlock_row[0],
                "unlock_days": unlock_row[1],
                "skill_id": unlock_row[2],
                "required_level": unlock_row[3],
                "required_condition": unlock_row[4],
            }

        content = _build_layer_tres(
            layer_id, uid, display_name, base_value, unlock, skill_uid_map
        )
        out = layers_dir / f"{layer_id}.tres"
        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            cur.execute(
                "UPDATE identity_layers SET uid = ? WHERE layer_id = ?", (uid, layer_id)
            )
            print(f"  layer → {out.name}")

    if not dry_run:
        conn.commit()


def export_items(conn: sqlite3.Connection, item_dir: Path, dry_run: bool) -> None:
    cur = conn.cursor()
    items = cur.execute(
        """
        SELECT i.item_id, i.uid, i.rarity, c.uid, c.category_id
        FROM items i
        LEFT JOIN categories c ON c.category_id = i.category_id
        ORDER BY i.item_id
        """
    ).fetchall()

    for item_id, item_uid, rarity, category_uid, category_id in items:
        item_uid = item_uid or _new_uid()
        layer_rows = cur.execute(
            """
            SELECT il.layer_id, il.uid, il.display_name, il.base_value
            FROM item_identity_layers iil
            JOIN identity_layers il ON il.layer_id = iil.layer_id
            WHERE iil.item_id = ?
            ORDER BY iil.sort_order
            """,
            (item_id,),
        ).fetchall()

        layers = [
            {
                "layer_id": r[0],
                "layer_uid": r[1],
                "display_name": r[2],
                "base_value": r[3],
            }
            for r in layer_rows
        ]

        content = _build_item_tres(
            item_id, item_uid, category_uid, category_id, rarity, layers
        )
        out = item_dir / f"{item_id}.tres"
        if dry_run:
            print(f"  [dry] would write {out}")
        else:
            out.write_text(content, encoding="utf-8")
            cur.execute(
                "UPDATE items SET uid = ? WHERE item_id = ?", (item_uid, item_id)
            )
            print(f"  item → {out.name}  ({len(layers)} layers)")

    if not dry_run:
        conn.commit()


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = Path(args.godot_root)
    super_categories_dir = root / "data" / "super_categories"
    categories_dir = root / "data" / "categories"
    layers_dir = root / "data" / "identity_layers"
    item_dir = root / "data" / "items"
    db_path = root / "data" / "_db" / "lot_haul.db"

    for d in (super_categories_dir, categories_dir, layers_dir, item_dir):
        d.mkdir(parents=True, exist_ok=True)

    if not db_path.exists():
        sys.exit(f"DB not found: {db_path}\nRun init.py first.")

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    skill_uid_map: dict[str, str] = {
        row[0]: row[1]
        for row in conn.execute(
            "SELECT skill_id, uid FROM skills WHERE uid IS NOT NULL"
        )
    }

    print("Exporting super_categories...")
    super_category_uid_map = export_super_categories(
        conn, super_categories_dir, args.dry_run
    )

    print("Exporting categories...")
    export_categories(conn, categories_dir, super_category_uid_map, args.dry_run)

    print("Exporting identity_layers...")
    export_identity_layers(conn, layers_dir, args.dry_run, skill_uid_map)

    print("Exporting items...")
    export_items(conn, item_dir, args.dry_run)

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
