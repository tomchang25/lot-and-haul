"""
check_sync.py
Compare .tres files on disk against lot_haul.db and report differences.

Outputs an HTML report to stdout (redirect to a file to open in a browser),
or prints a plain-text summary with --text.

Usage:
    python check_sync.py --godot-root /path/to/godot/project > sync_report.html
    python check_sync.py --godot-root /path/to/godot/project --text
"""

import argparse
import re
import sqlite3
import sys
from dataclasses import dataclass, field
from pathlib import Path


# ── .tres helpers (same as tres_to_db) ───────────────────────────────────────


def _header_uid(text: str) -> str | None:
    m = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', text)
    return m.group(1) if m else None


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


# ── Diff types ────────────────────────────────────────────────────────────────


@dataclass
class Row:
    table: str
    record_id: str
    status: str  # "only_tres" | "only_db" | "mismatch" | "ok"
    details: list[str] = field(default_factory=list)


# ── Checkers ──────────────────────────────────────────────────────────────────


def check_super_categories(
    conn: sqlite3.Connection, super_categories_dir: Path
) -> list[Row]:
    rows: list[Row] = []
    cur = conn.cursor()

    db_sc = {
        r[0]: {"display_name": r[1], "uid": r[2]}
        for r in cur.execute(
            "SELECT super_category_id, display_name, uid FROM super_categories"
        )
    }
    tres_sc: set[str] = set()

    for f in sorted(super_categories_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        super_cat_id = _field(text, "super_category_id") or f.stem
        tres_sc.add(super_cat_id)

        if super_cat_id not in db_sc:
            rows.append(
                Row(
                    "super_categories",
                    super_cat_id,
                    "only_tres",
                    ["exists on disk, missing from DB"],
                )
            )
            continue

        db = db_sc[super_cat_id]
        diffs: list[str] = []
        tres_name = _field(text, "display_name") or ""
        tres_uid = _header_uid(text) or ""

        if tres_name != db["display_name"]:
            diffs.append(f"display_name: tres={tres_name!r}  db={db['display_name']!r}")
        if db["uid"] and tres_uid and tres_uid != db["uid"]:
            diffs.append(f"uid: tres={tres_uid!r}  db={db['uid']!r}")

        rows.append(
            Row("super_categories", super_cat_id, "mismatch" if diffs else "ok", diffs)
        )

    for sc_id in db_sc:
        if sc_id not in tres_sc:
            rows.append(
                Row(
                    "super_categories",
                    sc_id,
                    "only_db",
                    ["exists in DB, no .tres file on disk"],
                )
            )

    return rows


def check_categories(
    conn: sqlite3.Connection,
    categories_dir: Path,
    super_category_uid_map: dict[str, str],
) -> list[Row]:
    rows: list[Row] = []
    cur = conn.cursor()

    db_cats = {
        r[0]: {
            "super_category": r[1],
            "display_name": r[2],
            "weight": r[3],
            "grid_size": r[4],
        }
        for r in cur.execute(
            "SELECT category_id, super_category, display_name, weight, grid_size FROM categories"
        )
    }
    tres_cats: set[str] = set()

    for f in sorted(categories_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        category_id = _field(text, "category_id") or f.stem
        tres_cats.add(category_id)

        if category_id not in db_cats:
            rows.append(
                Row(
                    "categories",
                    category_id,
                    "only_tres",
                    ["exists on disk, missing from DB"],
                )
            )
            continue

        db = db_cats[category_id]
        diffs: list[str] = []

        # Resolve super_category from the ExtResource reference.
        ext_res = _ext_resources(text)
        tres_super: str | None = None
        sc_m = re.search(r'super_category\s*=\s*ExtResource\("([^"]+)"\)', text)
        if sc_m:
            sc_uid = ext_res.get(sc_m.group(1), {}).get("uid")
            tres_super = super_category_uid_map.get(sc_uid or "")

        tres_name = _field(text, "display_name") or ""
        tres_w = float(_field(text, "weight") or 0.0)
        tres_gs = int(_field(text, "grid_size") or 1)

        if tres_super != db["super_category"]:
            diffs.append(
                f"super_category: tres={tres_super!r}  db={db['super_category']!r}"
            )
        if tres_name != db["display_name"]:
            diffs.append(f"display_name: tres={tres_name!r}  db={db['display_name']!r}")
        if abs(tres_w - db["weight"]) > 0.001:
            diffs.append(f"weight: tres={tres_w}  db={db['weight']}")
        if tres_gs != db["grid_size"]:
            diffs.append(f"grid_size: tres={tres_gs}  db={db['grid_size']}")

        rows.append(
            Row("categories", category_id, "mismatch" if diffs else "ok", diffs)
        )

    for cat_id in db_cats:
        if cat_id not in tres_cats:
            rows.append(
                Row(
                    "categories",
                    cat_id,
                    "only_db",
                    ["exists in DB, no .tres file on disk"],
                )
            )

    return rows


def check_identity_layers(conn: sqlite3.Connection, layers_dir: Path) -> list[Row]:
    rows: list[Row] = []
    cur = conn.cursor()

    db_layers = {
        r[0]: {"display_name": r[1], "base_value": r[2]}
        for r in cur.execute(
            "SELECT layer_id, display_name, base_value FROM identity_layers"
        )
    }
    db_unlocks = {
        r[0]: {
            "context": r[1],
            "unlock_days": r[2],
            "skill_id": r[3],
            "required_level": r[4],
            "required_condition": r[5],
        }
        for r in cur.execute(
            "SELECT layer_id, context, unlock_days, skill_id, required_level, "
            "required_condition FROM layer_unlock_actions"
        )
    }
    tres_layers: set[str] = set()

    for f in sorted(layers_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        layer_id = _field(text, "layer_id") or f.stem
        tres_layers.add(layer_id)

        if layer_id not in db_layers:
            rows.append(
                Row(
                    "identity_layers",
                    layer_id,
                    "only_tres",
                    ["exists on disk, missing from DB"],
                )
            )
            continue

        db = db_layers[layer_id]
        diffs: list[str] = []

        tres_name = _field(text, "display_name") or ""
        tres_value = int(_field(text, "base_value") or 0)

        if tres_name != db["display_name"]:
            diffs.append(f"display_name: tres={tres_name!r}  db={db['display_name']!r}")
        if tres_value != db["base_value"]:
            diffs.append(f"base_value: tres={tres_value}  db={db['base_value']}")

        # unlock_action
        unlock_raw = _field(text, "unlock_action")
        subs = _sub_resources(text)
        tres_unlock: dict | None = None
        if unlock_raw and unlock_raw != "null":
            um = re.match(r'SubResource\("([^"]+)"\)', unlock_raw)
            if um:
                tres_unlock = subs.get(um.group(1))

        db_unlock = db_unlocks.get(layer_id)

        if (tres_unlock is None) != (db_unlock is None):
            diffs.append(
                f"unlock_action: tres={'null' if tres_unlock is None else 'present'}"
                f"  db={'null' if db_unlock is None else 'present'}"
            )
        elif tres_unlock and db_unlock:
            t_ctx = int(tres_unlock.get("context", 1))
            t_tc = int(tres_unlock.get("unlock_days", 0))
            if t_ctx != db_unlock["context"]:
                diffs.append(f"unlock.context: tres={t_ctx}  db={db_unlock['context']}")
            if t_tc != db_unlock["unlock_days"]:
                diffs.append(
                    f"unlock.unlock_days: tres={t_tc}  db={db_unlock['unlock_days']}"
                )

        rows.append(
            Row("identity_layers", layer_id, "mismatch" if diffs else "ok", diffs)
        )

    for lid in db_layers:
        if lid not in tres_layers:
            rows.append(
                Row(
                    "identity_layers",
                    lid,
                    "only_db",
                    ["exists in DB, no .tres file on disk"],
                )
            )

    return rows


def check_items(
    conn: sqlite3.Connection,
    items_dir: Path,
    category_uid_map: dict[str, str],
) -> list[Row]:
    rows: list[Row] = []
    cur = conn.cursor()

    db_items = {
        r[0]: {"category_id": r[1], "rarity": r[2]}
        for r in cur.execute("SELECT item_id, category_id, rarity FROM items")
    }
    db_item_layers = {}
    for item_id, layer_id, sort_order in cur.execute(
        "SELECT item_id, layer_id, sort_order FROM item_identity_layers ORDER BY item_id, sort_order"
    ):
        db_item_layers.setdefault(item_id, []).append(layer_id)

    tres_items: set[str] = set()

    for f in sorted(items_dir.glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        item_id = _field(text, "item_id") or f.stem
        tres_items.add(item_id)

        if item_id not in db_items:
            rows.append(
                Row("items", item_id, "only_tres", ["exists on disk, missing from DB"])
            )
            continue

        db = db_items[item_id]
        diffs: list[str] = []

        tres_rarity = int(_field(text, "rarity") or 0)
        if tres_rarity != db["rarity"]:
            diffs.append(f"rarity: tres={tres_rarity}  db={db['rarity']}")

        ext_res = _ext_resources(text)
        tres_cat: str | None = None
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid")
            tres_cat = category_uid_map.get(cat_uid or "")
        if tres_cat != db["category_id"]:
            diffs.append(f"category_id: tres={tres_cat!r}  db={db['category_id']!r}")

        # layer order
        il_m = re.search(r"identity_layers\s*=\s*\[([^\]]*)\]", text)
        tres_layer_uids = []
        if il_m:
            for tag_m in re.finditer(r'ExtResource\("([^"]+)"\)', il_m.group(1)):
                lu = ext_res.get(tag_m.group(1), {}).get("uid")
                if lu:
                    tres_layer_uids.append(lu)

        tres_layer_ids = []
        for lu in tres_layer_uids:
            row = cur.execute(
                "SELECT layer_id FROM identity_layers WHERE uid = ?", (lu,)
            ).fetchone()
            if row:
                tres_layer_ids.append(row[0])

        db_layers = db_item_layers.get(item_id, [])
        if tres_layer_ids != db_layers:
            diffs.append(f"layer chain: tres={tres_layer_ids}  db={db_layers}")

        rows.append(Row("items", item_id, "mismatch" if diffs else "ok", diffs))

    for iid in db_items:
        if iid not in tres_items:
            rows.append(
                Row("items", iid, "only_db", ["exists in DB, no .tres file on disk"])
            )

    return rows


# ── Renderers ─────────────────────────────────────────────────────────────────


_STATUS_LABEL = {
    "ok": ("✓", "#2d7a2d", "In sync"),
    "mismatch": ("≠", "#b05a00", "Value mismatch"),
    "only_tres": ("←", "#a00000", "Only on disk"),
    "only_db": ("→", "#a00000", "Only in DB"),
}


def render_text(all_rows: list[Row]) -> None:
    counts = {"ok": 0, "mismatch": 0, "only_tres": 0, "only_db": 0}
    for r in all_rows:
        counts[r.status] += 1
        if r.status != "ok":
            sym, _, label = _STATUS_LABEL[r.status]
            print(f"  [{sym}] {r.table} / {r.record_id}  — {label}")
            for d in r.details:
                print(f"       {d}")

    print()
    print(
        f"  Total: {len(all_rows)}  |  "
        f"ok: {counts['ok']}  "
        f"mismatch: {counts['mismatch']}  "
        f"only_tres: {counts['only_tres']}  "
        f"only_db: {counts['only_db']}"
    )


def render_html(all_rows: list[Row]) -> str:
    counts = {"ok": 0, "mismatch": 0, "only_tres": 0, "only_db": 0}
    for r in all_rows:
        counts[r.status] += 1

    status_colors = {
        "ok": ("#e8f5e9", "#2d7a2d"),
        "mismatch": ("#fff3e0", "#b05a00"),
        "only_tres": ("#fdecea", "#a00000"),
        "only_db": ("#fdecea", "#a00000"),
    }

    table_rows_html = ""
    for r in all_rows:
        bg, fg = status_colors[r.status]
        sym, _, label = _STATUS_LABEL[r.status]
        details = "<br>".join(r.details) if r.details else ""
        table_rows_html += (
            f'<tr style="background:{bg}">'
            f'<td style="color:{fg};font-weight:600">{sym} {label}</td>'
            f"<td>{r.table}</td>"
            f'<td style="font-family:monospace">{r.record_id}</td>'
            f'<td style="font-family:monospace;font-size:12px;color:#555">{details}</td>'
            f"</tr>\n"
        )

    total = len(all_rows)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lot &amp; Haul — Sync Report</title>
<style>
  body {{ font-family: system-ui, sans-serif; margin: 2rem; color: #222; }}
  h1   {{ font-size: 1.4rem; margin-bottom: 0.5rem; }}
  .summary {{ display: flex; gap: 1.5rem; margin-bottom: 1.5rem; font-size: 14px; }}
  .pill {{ padding: 4px 12px; border-radius: 99px; font-weight: 600; }}
  table {{ border-collapse: collapse; width: 100%; font-size: 14px; }}
  th    {{ text-align: left; padding: 8px 12px; background: #f0f0f0;
           border-bottom: 2px solid #ccc; }}
  td    {{ padding: 7px 12px; border-bottom: 1px solid #e0e0e0; vertical-align: top; }}
  tr:hover td {{ filter: brightness(0.97); }}
</style>
</head>
<body>
<h1>Lot &amp; Haul — DB / .tres Sync Report</h1>
<div class="summary">
  <span class="pill" style="background:#e8f5e9;color:#2d7a2d">✓ {counts['ok']} ok</span>
  <span class="pill" style="background:#fff3e0;color:#b05a00">≠ {counts['mismatch']} mismatch</span>
  <span class="pill" style="background:#fdecea;color:#a00000">← {counts['only_tres']} only on disk</span>
  <span class="pill" style="background:#fdecea;color:#a00000">→ {counts['only_db']} only in DB</span>
  <span style="color:#888">total: {total}</span>
</div>
<table>
<thead><tr>
  <th>Status</th><th>Table</th><th>ID</th><th>Details</th>
</tr></thead>
<tbody>
{table_rows_html}
</tbody>
</table>
</body>
</html>"""


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--text", action="store_true", help="Print plain text instead of HTML"
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    super_categories_dir = root / "data" / "super_categories"
    categories_dir = root / "data" / "categories"
    layers_dir = root / "data" / "identity_layers"
    item_dir = root / "data" / "items"
    db_path = root / "data" / "_db" / "lot_haul.db"

    if not db_path.exists():
        sys.exit(f"DB not found: {db_path}\nRun init.py first.")

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    # uid → category_id (used by check_items)
    category_uid_map: dict[str, str] = {
        row[1]: row[0]
        for row in conn.execute(
            "SELECT category_id, uid FROM categories WHERE uid IS NOT NULL"
        )
    }

    # uid → super_category_id (used by check_categories)
    super_category_uid_map: dict[str, str] = {
        row[1]: row[0]
        for row in conn.execute(
            "SELECT super_category_id, uid FROM super_categories WHERE uid IS NOT NULL"
        )
    }

    all_rows: list[Row] = []
    all_rows += check_super_categories(conn, super_categories_dir)
    all_rows += check_categories(conn, categories_dir, super_category_uid_map)
    all_rows += check_identity_layers(conn, layers_dir)
    all_rows += check_items(conn, item_dir, category_uid_map)
    conn.close()

    if args.text:
        render_text(all_rows)
    else:
        print(render_html(all_rows))


if __name__ == "__main__":
    main()
