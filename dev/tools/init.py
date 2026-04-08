"""
init.py
Create lot_haul.db schema and insert one seed item (brass_lamp).

Existing database is left untouched if already present — schema uses
CREATE TABLE IF NOT EXISTS so it is safe to re-run.

Usage:
    python init.py --godot-root /path/to/godot/project
"""

import argparse
import sqlite3
from pathlib import Path


# ── Schema ────────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS skills (
    skill_id     TEXT    PRIMARY KEY,
    display_name TEXT    NOT NULL,
    max_level    INTEGER NOT NULL DEFAULT 5,
    uid          TEXT
);

CREATE TABLE IF NOT EXISTS super_categories (
    super_category_id TEXT    PRIMARY KEY,
    display_name      TEXT    NOT NULL,
    uid               TEXT
);

CREATE TABLE IF NOT EXISTS categories (
    category_id    TEXT    PRIMARY KEY,
    super_category TEXT    NOT NULL,
    display_name   TEXT    NOT NULL,
    weight         REAL    NOT NULL DEFAULT 0.0,
    shape_id       TEXT    NOT NULL DEFAULT 's1x1',
    uid            TEXT
);

CREATE TABLE IF NOT EXISTS identity_layers (
    layer_id     TEXT    PRIMARY KEY,
    display_name TEXT    NOT NULL,
    base_value   INTEGER NOT NULL,
    uid          TEXT
);

-- 1:1 with identity_layers; absent on the final layer of any chain.
-- context: 0=AUTO  1=HOME
CREATE TABLE IF NOT EXISTS layer_unlock_actions (
    layer_id           TEXT    PRIMARY KEY REFERENCES identity_layers(layer_id) ON DELETE CASCADE,
    context            INTEGER NOT NULL DEFAULT 1,
    time_cost          INTEGER NOT NULL DEFAULT 1,
    skill_id           TEXT    REFERENCES skills(skill_id),
    required_level     INTEGER NOT NULL DEFAULT 0,
    required_condition REAL    NOT NULL DEFAULT 0.0
);

-- rarity: 0=COMMON  1=UNCOMMON  2=RARE  3=EPIC  4=LEGENDARY
CREATE TABLE IF NOT EXISTS items (
    item_id     TEXT    PRIMARY KEY,
    category_id TEXT    REFERENCES categories(category_id),
    rarity      INTEGER NOT NULL DEFAULT 0,
    uid         TEXT
);

CREATE TABLE IF NOT EXISTS item_identity_layers (
    item_id    TEXT    NOT NULL REFERENCES items(item_id)    ON DELETE CASCADE,
    layer_id   TEXT    NOT NULL REFERENCES identity_layers(layer_id),
    sort_order INTEGER NOT NULL,
    PRIMARY KEY (item_id, sort_order)
);
"""

# ── Seed data (brass_lamp) ────────────────────────────────────────────────────

_SEED_SKILL = ("appraisal", "Appraisal", 5)

_SEED_SUPER_CATEGORIES = [
    ("decorative", "Decorative"),
    ("fashion", "Fashion"),
    ("fine_art", "Fine Art"),
    ("vehicle", "Vehicle"),
]


_SEED_CATEGORY = ("oil_lamp", "Decorative", "Oil Lamp", 3.0, "s1x2")

_SEED_LAYERS = [
    # (layer_id, display_name, base_value, unlock_context, time_cost, skill_id, req_level)
    ("lamp_shaped_object", "Lamp-Shaped Object", 80, 0, 0, None, 0),
    ("antique_oil_lamp", "Antique Oil Lamp", 220, 1, 2, None, 0),
    (
        "signed_duplex_burner_lamp",
        "Signed Duplex Burner Lamp",
        950,
        None,
        None,
        None,
        0,
    ),
]

_SEED_ITEM = ("brass_lamp", "oil_lamp", 2)

_SEED_ITEM_LAYERS = [
    "lamp_shaped_object",
    "antique_oil_lamp",
    "signed_duplex_burner_lamp",
]


# ── Seeder ────────────────────────────────────────────────────────────────────


def _seed(conn: sqlite3.Connection) -> None:
    cur = conn.cursor()

    # super_categories
    for sc_id, sc_name in _SEED_SUPER_CATEGORIES:
        cur.execute(
            "INSERT OR IGNORE INTO super_categories (super_category_id, display_name) VALUES (?,?)",
            (sc_id, sc_name),
        )

    # skill
    skill_id, display_name, max_level = _SEED_SKILL
    cur.execute(
        "INSERT OR IGNORE INTO skills (skill_id, display_name, max_level) VALUES (?,?,?)",
        (skill_id, display_name, max_level),
    )

    # category
    cat_id, super_cat, cat_name, weight, shape_id = _SEED_CATEGORY
    cur.execute(
        "INSERT OR IGNORE INTO categories "
        "(category_id, super_category, display_name, weight, shape_id) VALUES (?,?,?,?,?)",
        (cat_id, super_cat, cat_name, weight, shape_id),
    )

    # layers
    for layer_id, disp, value, ctx, tc, sid, rlv in _SEED_LAYERS:
        cur.execute(
            "INSERT OR IGNORE INTO identity_layers (layer_id, display_name, base_value) VALUES (?,?,?)",
            (layer_id, disp, value),
        )
        if ctx is not None:
            cur.execute(
                "INSERT OR IGNORE INTO layer_unlock_actions "
                "(layer_id, context, time_cost, skill_id, required_level) VALUES (?,?,?,?,?)",
                (layer_id, ctx, tc or 0, sid, rlv),
            )

    # item
    item_id, item_cat, rarity = _SEED_ITEM
    cur.execute(
        "INSERT OR IGNORE INTO items (item_id, category_id, rarity) VALUES (?,?,?)",
        (item_id, item_cat, rarity),
    )
    cur.execute("DELETE FROM item_identity_layers WHERE item_id = ?", (item_id,))
    for order, lid in enumerate(_SEED_ITEM_LAYERS):
        cur.execute(
            "INSERT INTO item_identity_layers (item_id, layer_id, sort_order) VALUES (?,?,?)",
            (item_id, lid, order),
        )

    conn.commit()
    print("  seed: brass_lamp inserted")


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    args = parser.parse_args()

    root = Path(args.godot_root)
    db_dir = root / "data" / "_db"
    db_dir.mkdir(parents=True, exist_ok=True)
    db_path = db_dir / "lot_haul.db"

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA)
    print("Schema ready.")

    _seed(conn)
    conn.close()
    print(f"Done → {db_path}")


if __name__ == "__main__":
    main()
