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

var stamina: int = 0
var max_stamina: int = 30

var actions_remaining: int = 0 # resets each lot from LotData.action_quota

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(entry: LotEntry) -> RunRecord:
    var r := RunRecord.new()
    r.lot_entry = entry

    # TODO: get this value from car config if implemented
    r.max_stamina = 30
    r.stamina = r.max_stamina

    return r
