# run_record.gd
# Runtime record for a single warehouse run.
class_name RunRecord
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var lot_entry: LotEntry # null until set_lot() is called

var lot_items: Array[ItemEntry]:
    get:
        return lot_entry.item_entries if lot_entry else []
var won_items: Array[ItemEntry] = []
var cargo_items: Array[ItemEntry] = []
var last_lot_won_items: Array[ItemEntry] = []

var onsite_proceeds: int = 0
var paid_price: int = 0
var net: int = 0

var stamina: int = 0
var max_stamina: int = 30
var car_config: CarConfig = null

var actions_remaining: int = 0 # resets each lot from LotData.action_quota

# ── Location / browse state ───────────────────────────────────────────────────

var location_data: LocationData = null

# Sampled lot list for this location visit. Populated on first entry to
# LocationBrowseScene, persists across scene transitions.
var browse_lots: Array[LotData] = []

# Index into browse_lots pointing at the current (or next) lot to show.
var browse_index: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(location: LocationData, car: CarConfig) -> RunRecord:
    var r := RunRecord.new()
    r.location_data = location
    r.car_config = car
    r.max_stamina = car.stamina_cap
    r.stamina = r.max_stamina

    return r

# ══ Lot management ════════════════════════════════════════════════════════════


# Sets the active lot entry and resets the per-lot action counter.
func set_lot(entry: LotEntry) -> void:
    lot_entry = entry
    actions_remaining = entry.lot_data.action_quota
    last_lot_won_items.clear()
