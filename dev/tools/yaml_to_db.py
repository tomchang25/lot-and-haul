"""
yaml_to_db.py
Import categories, identity_layers, and items from a YAML file into lot_haul.db.

All inserts use UPSERT (ON CONFLICT DO UPDATE), so re-running is safe.
UIDs already present in the DB are preserved. New rows get no UID — export_tres
will assign them on first export.

Usage:
    python yaml_to_db.py --godot-root /path/to/godot/project --yaml decorative_items.yaml
    python yaml_to_db.py --godot-root /path/to/godot/project --yaml decorative_items.yaml --dry-run
"""

import argparse
import sqlite3
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")


# ── Importers ─────────────────────────────────────────────────────────────────

_KNOWN_SKILLS = {
    "appraisal":      "Appraisal",
    "authentication": "Authentication",
    "mechanical":     "Mechanical",
}


def ensure_skills(cur: sqlite3.Cursor, layers: list[dict], dry_run: bool) -> None:
    """Upsert any skill referenced by unlock_actions that isn't in the DB yet."""
    needed: set[str] = set()
    for layer in layers:
        unlock = layer.get("unlock_action")
        if unlock and unlock.get("required_skill"):
            needed.add(unlock["required_skill"])

    for sid in sorted(needed):
        disp = _KNOWN_SKILLS.get(sid, sid.replace("_", " ").title())
        if dry_run:
            print(f"  [dry] skill: {sid}")
        else:
            cur.execute(
                """
                INSERT INTO skills (skill_id, display_name, max_level)
                VALUES (?, ?, 5)
                ON CONFLICT(skill_id) DO NOTHING
                """,
                (sid, disp),
            )
            print(f"  skill: {sid}")


def import_categories(cur: sqlite3.Cursor, categories: list[dict], dry_run: bool) -> int:
    count = 0
    for cat in categories:
        cat_id      = cat["category_id"]
        super_cat   = cat["super_category"]
        disp        = cat["display_name"]
        weight      = float(cat.get("weight", 0.0))
        grid_size   = int(cat.get("grid_size", 1))

        if dry_run:
            print(f"  [dry] category: {cat_id}")
        else:
            cur.execute(
                """
                INSERT INTO categories
                    (category_id, super_category, display_name, weight, grid_size)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(category_id) DO UPDATE SET
                    super_category = excluded.super_category,
                    display_name   = excluded.display_name,
                    weight         = excluded.weight,
                    grid_size      = excluded.grid_size
                """,
                (cat_id, super_cat, disp, weight, grid_size),
            )
            print(f"  category: {cat_id}")
        count += 1
    return count


def import_identity_layers(
    cur: sqlite3.Cursor, layers: list[dict], dry_run: bool
) -> int:
    count = 0
    for layer in layers:
        layer_id  = layer["layer_id"]
        disp      = layer["display_name"]
        value     = int(layer["base_value"])
        unlock    = layer.get("unlock_action")

        if dry_run:
            print(f"  [dry] layer: {layer_id}")
            count += 1
            continue

        cur.execute(
            """
            INSERT INTO identity_layers (layer_id, display_name, base_value)
            VALUES (?, ?, ?)
            ON CONFLICT(layer_id) DO UPDATE SET
                display_name = excluded.display_name,
                base_value   = excluded.base_value
            """,
            (layer_id, disp, value),
        )

        # Remove old unlock_action unconditionally — will re-insert if present
        cur.execute(
            "DELETE FROM layer_unlock_actions WHERE layer_id = ?", (layer_id,)
        )

        if unlock is not None:
            ctx     = int(unlock["context"])
            tc      = int(unlock.get("time_cost", 0))
            sid     = unlock.get("required_skill")       or None
            rlv     = int(unlock.get("required_level", 0))
            rcond   = float(unlock.get("required_condition", 0.0))

            cur.execute(
                """
                INSERT INTO layer_unlock_actions
                    (layer_id, context, time_cost, skill_id,
                     required_level, required_condition)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (layer_id, ctx, tc, sid, rlv, rcond),
            )

        print(f"  layer: {layer_id}")
        count += 1
    return count


def import_items(cur: sqlite3.Cursor, items: list[dict], dry_run: bool) -> int:
    count = 0
    for item in items:
        item_id    = item["item_id"]
        cat_id     = item["category_id"]
        rarity     = int(item.get("rarity", 0))
        layer_ids  = item.get("layer_ids", [])

        if dry_run:
            print(f"  [dry] item: {item_id}  ({len(layer_ids)} layers)")
            count += 1
            continue

        cur.execute(
            """
            INSERT INTO items (item_id, category_id, rarity)
            VALUES (?, ?, ?)
            ON CONFLICT(item_id) DO UPDATE SET
                category_id = excluded.category_id,
                rarity      = excluded.rarity
            """,
            (item_id, cat_id, rarity),
        )

        cur.execute(
            "DELETE FROM item_identity_layers WHERE item_id = ?", (item_id,)
        )
        for order, lid in enumerate(layer_ids):
            cur.execute(
                """
                INSERT INTO item_identity_layers (item_id, layer_id, sort_order)
                VALUES (?, ?, ?)
                """,
                (item_id, lid, order),
            )

        print(f"  item: {item_id}  ({len(layer_ids)} layers)")
        count += 1
    return count


# ── Validation ────────────────────────────────────────────────────────────────


def _validate(data: dict) -> list[str]:
    """Return a list of error strings. Empty list means OK."""
    errors: list[str] = []

    known_layer_ids: set[str] = {l["layer_id"] for l in data.get("identity_layers", [])}
    known_cat_ids:   set[str] = {c["category_id"] for c in data.get("categories", [])}

    for layer in data.get("identity_layers", []):
        lid    = layer.get("layer_id", "?")
        unlock = layer.get("unlock_action")

        if unlock is None:
            continue  # final layer — OK

        ctx = unlock.get("context")
        if ctx not in (0, 1):
            errors.append(f"layer '{lid}': unlock_action.context must be 0 or 1, got {ctx!r}")

        if ctx == 1 and not unlock.get("time_cost"):
            errors.append(f"layer '{lid}': context=1 (HOME) requires time_cost >= 1")

        if unlock.get("required_level") and not unlock.get("required_skill"):
            errors.append(f"layer '{lid}': required_level set without required_skill")

        sid = unlock.get("required_skill")
        if sid and sid not in ("appraisal", "authentication", "mechanical"):
            errors.append(f"layer '{lid}': unknown required_skill '{sid}'")

    for item in data.get("items", []):
        iid       = item.get("item_id", "?")
        layer_ids = item.get("layer_ids", [])

        if item.get("category_id") not in known_cat_ids:
            errors.append(f"item '{iid}': category_id '{item.get('category_id')}' not in this file")

        if len(layer_ids) < 2:
            errors.append(f"item '{iid}': must have at least 2 layer_ids")

        for lid in layer_ids:
            if lid not in known_layer_ids:
                errors.append(f"item '{iid}': layer_id '{lid}' not defined in identity_layers")

        # check layer[0] is AUTO and layer[-1] is null
        if layer_ids:
            first = next(
                (l for l in data["identity_layers"] if l["layer_id"] == layer_ids[0]),
                None,
            )
            if first:
                ctx0 = (first.get("unlock_action") or {}).get("context")
                if ctx0 != 0:
                    errors.append(
                        f"item '{iid}': layer[0] '{layer_ids[0]}' must have context=0 (AUTO)"
                    )

            last = next(
                (l for l in data["identity_layers"] if l["layer_id"] == layer_ids[-1]),
                None,
            )
            if last and last.get("unlock_action") is not None:
                errors.append(
                    f"item '{iid}': final layer '{layer_ids[-1]}' must have unlock_action: null"
                )

    return errors


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    parser.add_argument("--yaml",       required=True, help="Path to the YAML file")
    parser.add_argument("--dry-run",    action="store_true")
    args = parser.parse_args()

    yaml_path = Path(args.yaml)
    if not yaml_path.exists():
        sys.exit(f"YAML file not found: {yaml_path}")

    data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))

    print("Validating...")
    errors = _validate(data)
    if errors:
        print(f"  {len(errors)} error(s) found — aborting:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")

    db_path = Path(args.godot_root) / "data" / "_db" / "lot_haul.db"
    if not db_path.exists():
        sys.exit(f"DB not found: {db_path}\nRun init.py first.")

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    cur = conn.cursor()

    categories = data.get("categories", [])
    layers     = data.get("identity_layers", [])
    items      = data.get("items", [])

    print(f"Importing categories ({len(categories)})...")
    import_categories(cur, categories, args.dry_run)

    print("Ensuring skills...")
    ensure_skills(cur, layers, args.dry_run)

    print(f"Importing identity_layers ({len(layers)})...")
    import_identity_layers(cur, layers, args.dry_run)

    print(f"Importing items ({len(items)})...")
    import_items(cur, items, args.dry_run)

    if not args.dry_run:
        conn.commit()

    conn.close()
    total = len(categories) + len(layers) + len(items)
    tag = "[dry run] " if args.dry_run else ""
    print(f"\n{tag}Done — {total} records processed.")


if __name__ == "__main__":
    main()
