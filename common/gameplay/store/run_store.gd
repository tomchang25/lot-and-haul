# run_store.gd
# Session-scoped Store for a single warehouse run. Holds all mutable run state
# carries no save payload (not registered with SaveManager). Created and owned
# by RunManager for the duration of a run; null between runs.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name RunStore
extends StoreBase

# ── Backing variables ──────────────────────────────────────────────────────────

var _lot_entry: LotEntry
var _won_items: Array[ItemEntry] = []
var _cargo_items: Array[ItemEntry] = []
var _trailer_items: Array[ItemEntry] = []
var _last_lot_won_items: Array[ItemEntry] = []

var _onsite_proceeds: int = 0
var _paid_price: int = 0
var _net: int = 0
var _entry_fee: int = 0
var _fuel_cost: int = 0

var _stamina: int = 0
var _max_stamina: int = 30
var _car_data: CarData = null

var _inspection_ap_cap: int = Economy.INSPECTION_AP_CAP
var _refill_metric: int = Economy.INSPECTION_REFILL_METRIC_DEFAULT
var _actions_remaining: int = 0

var _location_data: LocationData = null
var _browse_lots: Array[LotData] = []
var _browse_index: int = 0

# ── Getters (read-public) ──────────────────────────────────────────────────────

var lot_entry: LotEntry:
    get:
        return _lot_entry

## Shallow duplicate of the active lot's items (ItemEntry refs shared).
## Derived from lot_entry.item_entries. Empty when no lot is active.
var lot_items: Array[ItemEntry]:
    get:
        return _lot_entry.item_entries.duplicate() if _lot_entry else []

## Shallow duplicate of won items accumulated during the run (ItemEntry refs shared).
var won_items: Array[ItemEntry]:
    get:
        return _won_items.duplicate()

## Shallow duplicate of cargo items committed for transport (ItemEntry refs shared).
var cargo_items: Array[ItemEntry]:
    get:
        return _cargo_items.duplicate()

## Shallow duplicate of trailer items committed for transport (ItemEntry refs shared).
var trailer_items: Array[ItemEntry]:
    get:
        return _trailer_items.duplicate()

## Shallow duplicate of the last lot's won items (ItemEntry refs shared).
var last_lot_won_items: Array[ItemEntry]:
    get:
        return _last_lot_won_items.duplicate()

var onsite_proceeds: int:
    get:
        return _onsite_proceeds

var paid_price: int:
    get:
        return _paid_price

var net: int:
    get:
        return _net

var entry_fee: int:
    get:
        return _entry_fee

var fuel_cost: int:
    get:
        return _fuel_cost

var stamina: int:
    get:
        return _stamina

var max_stamina: int:
    get:
        return _max_stamina

var car_data: CarData:
    get:
        return _car_data

## Per-lot AP cap. Inspection within one lot never exceeds this value.
var inspection_ap_cap: int:
    get:
        return _inspection_ap_cap

## Reserve pool that refills actions_remaining toward the cap at lot boundaries.
var refill_metric: int:
    get:
        return _refill_metric

## Current spendable AP for the active lot.
var actions_remaining: int:
    get:
        return _actions_remaining

var location_data: LocationData:
    get:
        return _location_data

## Shallow duplicate of the browse lot list (LotData refs shared).
var browse_lots: Array[LotData]:
    get:
        return _browse_lots.duplicate()

var browse_index: int:
    get:
        return _browse_index

# ══ Construction ══════════════════════════════════════════════════════════════


## Initializes all construction-time fields for a new run. Called once by
## RunManager.create_run_store() immediately after RunStore.new().
func initialize(
        p_location: LocationData,
        p_car: CarData,
        p_ap_cap: int,
        p_refill: int,
        p_entry_fee: int,
        p_fuel_cost: int,
) -> void:
    _location_data = p_location
    _car_data = p_car
    _max_stamina = p_car.stamina_cap if p_car != null else 30
    _stamina = _max_stamina
    _inspection_ap_cap = p_ap_cap
    _refill_metric = p_refill
    _actions_remaining = p_ap_cap
    _entry_fee = p_entry_fee
    _fuel_cost = p_fuel_cost

# ══ Lot management ════════════════════════════════════════════════════════════


## Sets the active lot entry and refills actions_remaining toward the cap from
## the reserve, paying only the deficit. Partial refill when reserve is short.
## No refill when the reserve is already empty — later lots run on leftover AP.
func set_lot(entry: LotEntry) -> void:
    _lot_entry = entry
    _last_lot_won_items.clear()

    # Two-tier deficit refill: only the shortfall below the cap is drawn from
    # the reserve. Under-spending on a weak lot preserves reserve for later lots.
    var deficit: int = _inspection_ap_cap - _actions_remaining
    if deficit > 0 and _refill_metric > 0:
        var take: int = mini(deficit, _refill_metric)
        _actions_remaining += take
        _refill_metric -= take

# ══ Run-phase mutations ════════════════════════════════════════════════════════


## Deducts [param cost] AP from the current inspection pool.
func deduct_ap(cost: int) -> void:
    _actions_remaining -= cost


## Records a won lot: saves [param items] as last_lot_won_items, adds
## [param price] to paid_price, and appends items to the cumulative won list.
func record_lot_win(items: Array[ItemEntry], price: int) -> void:
    _last_lot_won_items = items.duplicate()
    _paid_price += price
    _won_items.append_array(items)


## Initialises browse state for a fresh location visit: assigns [param lots]
## and resets browse_index to 0. Called when LotBrowseScene first loads.
func init_browse(lots: Array[LotData]) -> void:
    _browse_lots = lots
    _browse_index = 0


## Advances browse_index by one (player passed or entered a lot).
func advance_browse_index() -> void:
    _browse_index += 1


## Commits cargo loading result: final [param cargo], [param trailer] items,
## and [param proceeds] from abandoned items sold on-site.
func set_cargo_result(
        cargo: Array[ItemEntry],
        trailer: Array[ItemEntry],
        proceeds: int,
) -> void:
    _cargo_items = cargo
    _trailer_items = trailer
    _onsite_proceeds = proceeds
