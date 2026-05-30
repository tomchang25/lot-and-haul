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
var trailer_items: Array[ItemEntry] = []
var last_lot_won_items: Array[ItemEntry] = []

var onsite_proceeds: int = 0
var paid_price: int = 0
var net: int = 0
var entry_fee: int = 0
var fuel_cost: int = 0

var stamina: int = 0
var max_stamina: int = 30
var car_data: CarData = null

# ── Two-tier auction AP ───────────────────────────────────────────────────────

## Per-lot AP cap. Inspection within one lot never exceeds this value.
## Hard-capped — buffs raise this ceiling rather than adding to actions_remaining.
var inspection_ap_cap: int = Economy.INSPECTION_AP_CAP

## Reserve pool that refills actions_remaining toward the cap at lot boundaries.
## Pays only the deficit (cap − current); partial when the reserve is short.
## When empty, no refill occurs and later lots run on whatever AP is left.
var refill_metric: int = Economy.INSPECTION_REFILL_METRIC_DEFAULT

## Current spendable AP for the active lot.
var actions_remaining: int = 0

# ── Location / browse state ───────────────────────────────────────────────────

var location_data: LocationData = null

# Sampled lot list for this location visit. Populated on first entry to
# LotBrowseScene, persists across scene transitions.
var browse_lots: Array[LotData] = []

# Index into browse_lots pointing at the current (or next) lot to show.
var browse_index: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(location: LocationData, car: CarData) -> RunRecord:
    var r := RunRecord.new()
    r.location_data = location
    r.car_data = car
    r.max_stamina = car.stamina_cap
    r.stamina = r.max_stamina
    # Seed the first lot with a full AP pool.
    r.actions_remaining = r.inspection_ap_cap
    r.compute_travel_costs()

    return r


func compute_travel_costs() -> void:
    entry_fee = location_data.entry_fee if location_data else 0
    fuel_cost = car_data.fuel_cost_per_day * location_data.travel_days if location_data and car_data else 0

# ══ Lot management ════════════════════════════════════════════════════════════


## Sets the active lot entry and refills actions_remaining toward the cap from
## the reserve, paying only the deficit. Partial refill when reserve is short.
## No refill when the reserve is already empty — later lots run on leftover AP.
func set_lot(entry: LotEntry) -> void:
    lot_entry = entry
    last_lot_won_items.clear()

    # Two-tier deficit refill: only the shortfall below the cap is drawn from
    # the reserve. Under-spending on a weak lot preserves reserve for later lots.
    var deficit: int = inspection_ap_cap - actions_remaining
    if deficit > 0 and refill_metric > 0:
        var take: int = mini(deficit, refill_metric)
        actions_remaining += take
        refill_metric -= take
