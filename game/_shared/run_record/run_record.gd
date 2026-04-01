class_name RunRecord
extends RefCounted

# ── Lot phase ─────────────────────────────────────────────────────────────────
var lot_entry: LotEntry # rolled factors + item_entries
var lot_result: Dictionary = { } # { "paid_price": int, "won_items": Array[ItemEntry] }

# ── Cargo phase ───────────────────────────────────────────────────────────────
var cargo_items: Array[ItemEntry] = []

# ── Appraisal phase ───────────────────────────────────────────────────────────
var onsite_proceeds: int = 0
var sell_value: int = 0
var paid_price: int = 0
var net: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(entry: LotEntry) -> RunRecord:
    var r := RunRecord.new()
    r.lot_entry = entry
    return r
