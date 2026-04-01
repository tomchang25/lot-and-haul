# run_record.gd
# Runtime record for a single warehouse run.
class_name RunRecord
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var lot_entry: LotEntry # rolled factors + item_entries

var lot_items: Array[ItemEntry]:
    get:
        return lot_entry.item_entries if lot_entry else []
var won_items: Array[ItemEntry] = []
var cargo_items: Array[ItemEntry] = []

var onsite_proceeds: int = 0
var sell_value: int = 0
var paid_price: int = 0
var net: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(entry: LotEntry) -> RunRecord:
    var r := RunRecord.new()
    r.lot_entry = entry
    return r
