"""
init_db.py
Create lot_haul.db with schema, then seed from existing .tres files.

Usage:
    python init_db.py --godot-root /path/to/godot/project
"""

import argparse
import json
import re
import sqlite3
from pathlib import Path


# ── Schema ────────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS veiled_types (
    type_id            TEXT PRIMARY KEY,
    display_label      TEXT NOT NULL,
    base_veiled_price  INTEGER NOT NULL,
    uid                TEXT            -- Godot uid, e.g. uid://bo7p4vl0ihhox
);

CREATE TABLE IF NOT EXISTS items (
    id             TEXT PRIMARY KEY,  -- filename stem, e.g. "typewriter"
    item_name      TEXT NOT NULL,
    true_value     INTEGER NOT NULL,
    weight         REAL NOT NULL,
    grid_size      INTEGER NOT NULL,
    super_category TEXT NOT NULL,
    category       TEXT NOT NULL,
    clues          TEXT NOT NULL,     -- JSON array
    uid            TEXT               -- Godot uid for this .tres
);

CREATE TABLE IF NOT EXISTS item_veiled_types (
    item_id    TEXT NOT NULL REFERENCES items(id),
    type_id    TEXT NOT NULL REFERENCES veiled_types(type_id),
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (item_id, type_id)
);
"""


# ── GDScript default reader ───────────────────────────────────────────────────

_GD_LITERALS: dict[str, object] = {"true": True, "false": False, "null": None}

_GD_TYPE_CAST: dict[str, type] = {
    "int": int,
    "float": float,
    "bool": bool,
    "String": str,
}


def _cast_gd_default(raw: str, type_hint: str) -> object:
    """Convert a raw GDScript default string to a Python scalar."""
    raw = raw.strip().strip('"')
    if raw in _GD_LITERALS:
        return _GD_LITERALS[raw]
    cast = _GD_TYPE_CAST.get(type_hint)
    if cast:
        try:
            return cast(raw)
        except (ValueError, TypeError):
            pass
    for t in (int, float):
        try:
            return t(raw)
        except ValueError:
            pass
    return raw


def parse_gd_defaults(gd_path: Path) -> dict[str, object]:
    """
    Parse @export lines from a .gd file and return {field_name: default_value}.
    Handles:
        @export var name: Type = default
        @export var name: Array[...] = []   → returns []
    Skips Resource-typed arrays (e.g. Array[VeiledType]) — not scalar defaults.
    """
    defaults: dict[str, object] = {}
    pattern = re.compile(r"@export\s+var\s+(\w+)\s*:\s*([\w\[\]]+)\s*(?:=\s*(.+))?")
    for line in gd_path.read_text(encoding="utf-8").splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        name, type_hint, raw = m.group(1), m.group(2), m.group(3)
        if raw is None:
            continue
        raw = raw.strip()
        if raw == "[]":
            defaults[name] = []
        elif raw.startswith("[") or raw.startswith("{"):
            continue
        else:
            defaults[name] = _cast_gd_default(raw, type_hint)
    return defaults


# ── .tres parsers ─────────────────────────────────────────────────────────────


def _get(text: str, key: str) -> str | None:
    m = re.search(rf'^{key}\s*=\s*"?([^"\n]+)"?', text, re.MULTILINE)
    return m.group(1).strip() if m else None


def _get_int(text: str, key: str) -> int | None:
    v = _get(text, key)
    return int(v) if v else None


def _get_float(text: str, key: str) -> float | None:
    v = _get(text, key)
    return float(v) if v else None


def _get_clues(text: str) -> list[str]:
    m = re.search(r"clues\s*=\s*Array\[String\]\(\[(.*?)\]\)", text, re.DOTALL)
    if not m:
        return []
    return re.findall(r'"([^"]*)"', m.group(1))


def _get_header_uid(text: str) -> str | None:
    m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
    return m.group(1) if m else None


def _get_ext_uids(text: str) -> dict[str, str]:
    """Return {id_tag: uid} for all ext_resource lines that have a uid."""
    result = {}
    for m in re.finditer(r'\[ext_resource[^\]]*uid="([^"]+)"[^\]]*id="([^"]+)"', text):
        result[m.group(2)] = m.group(1)
    return result


def _get_veiled_type_refs(text: str) -> list[str]:
    """Return ordered list of ext_resource id tags for veiled_types array."""
    m = re.search(
        r"veiled_types\s*=\s*Array\[ExtResource\([^)]+\)\]\(\[(.*?)\]\)",
        text,
        re.DOTALL,
    )
    if not m:
        return []
    return re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))


# ── Seeders ───────────────────────────────────────────────────────────────────


def seed_veiled_types(conn: sqlite3.Connection, vt_dir: Path) -> None:
    cur = conn.cursor()
    for f in sorted(vt_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        type_id = _get(text, "type_id")
        label = _get(text, "display_label")
        price = _get_int(text, "base_veiled_price")
        uid = _get_header_uid(text)

        if not type_id:
            print(f"  skip {f.name}: no type_id")
            continue

        cur.execute(
            """
            INSERT INTO veiled_types (type_id, display_label, base_veiled_price, uid)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(type_id) DO UPDATE SET
                display_label     = excluded.display_label,
                base_veiled_price = excluded.base_veiled_price,
                uid               = excluded.uid
            """,
            (type_id, label, price, uid),
        )
        print(f"  veiled_type: {type_id}")
    conn.commit()


def seed_items(
    conn: sqlite3.Connection,
    items_dir: Path,
    gd_defaults: dict[str, object],
) -> None:
    cur = conn.cursor()

    # Build uid → type_id map from DB
    vt_uid_map = {
        row[0]: row[1]
        for row in cur.execute(
            "SELECT uid, type_id FROM veiled_types WHERE uid IS NOT NULL"
        )
    }

    def _field(text: str, key: str, getter, gd_key: str | None = None) -> object:
        """Read a field from .tres; fall back to gd_defaults if absent."""
        val = getter(text, key)
        if val is None:
            val = gd_defaults.get(gd_key or key)
        return val

    for f in sorted(items_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        item_id = f.stem
        ext_uids = _get_ext_uids(text)
        clues = _get_clues(text)

        cur.execute(
            """
            INSERT INTO items
                (id, item_name, true_value, weight, grid_size,
                 super_category, category, clues, uid)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                item_name      = excluded.item_name,
                true_value     = excluded.true_value,
                weight         = excluded.weight,
                grid_size      = excluded.grid_size,
                super_category = excluded.super_category,
                category       = excluded.category,
                clues          = excluded.clues,
                uid            = excluded.uid
            """,
            (
                item_id,
                _field(text, "item_name", _get),
                _field(text, "true_value", _get_int),
                _field(text, "weight", _get_float),
                _field(text, "grid_size", _get_int),
                _field(text, "super_category", _get),
                _field(text, "category", _get),
                json.dumps(clues),
                _get_header_uid(text),
            ),
        )

        # Junction rows
        cur.execute("DELETE FROM item_veiled_types WHERE item_id = ?", (item_id,))
        for order, tag in enumerate(_get_veiled_type_refs(text)):
            type_id = vt_uid_map.get(ext_uids.get(tag))
            if type_id:
                cur.execute(
                    """
                    INSERT OR IGNORE INTO item_veiled_types (item_id, type_id, sort_order)
                    VALUES (?, ?, ?)
                    """,
                    (item_id, type_id, order),
                )

        print(f"  item: {item_id}")
    conn.commit()


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--godot-root",
        required=True,
        help="Path to Godot project root (contains data/)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    vt_dir = root / "data" / "veiled_types"
    item_dir = root / "data" / "items"
    gd_dir = root / "data" / "_definitions"
    db_dir = root / "data" / "_db"

    item_gd = gd_dir / "item_data.gd"
    gd_defaults: dict[str, object] = {}
    if item_gd.exists():
        gd_defaults = parse_gd_defaults(item_gd)
        print(f"Loaded GD defaults from {item_gd.name}: {gd_defaults}")
    else:
        print(f"Warning: {item_gd} not found — no fallback defaults available")

    db_dir.mkdir(parents=True, exist_ok=True)
    db_path = db_dir / "lot_haul.db"
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA)

    print("Seeding veiled_types...")
    seed_veiled_types(conn, vt_dir)

    print("Seeding items...")
    seed_items(conn, item_dir, gd_defaults)

    conn.close()
    print(f"\nDone → {db_path}")


if __name__ == "__main__":
    main()
