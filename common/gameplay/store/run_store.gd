# run_store.gd
# Session-scoped Store for a single warehouse run. Holds per-run cumulative and
# configuration state. Carries no save payload (not registered with SaveManager).
# Created and owned by RunManager for the duration of a run; null between runs.
#
# Per-lot mutable state (active entry, AP, win result) lives in LotStore.
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name RunStore
extends StoreBase

# ── Backing variables ──────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
var _cargo_items: Array[ItemEntry] = []
var _trailer_items: Array[ItemEntry] = []

var _onsite_proceeds: int = 0
var _paid_price: int = 0
var _entry_fee: int = 0
var _fuel_cost: int = 0

var _stamina: int = 0
var _max_stamina: int = 30
var _car_data: CarData = null

var _inspection_ap_cap: int = Economy.INSPECTION_AP_CAP
var _refill_metric: int = Economy.INSPECTION_REFILL_METRIC_DEFAULT

var _location_data: LocationData = null
var _browse_lots: Array[LotData] = []
var _browse_index: int = 0

# ── Getters (read-public) ──────────────────────────────────────────────────────

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

var onsite_proceeds: int:
    get:
        return _onsite_proceeds

var paid_price: int:
    get:
        return _paid_price

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
    _entry_fee = p_entry_fee
    _fuel_cost = p_fuel_cost

# ══ Run-phase mutations ════════════════════════════════════════════════════════


## Draws AP from the reserve to cover [param deficit] points. Returns the actual
## amount taken (may be less than deficit when the reserve is low). Called by
## RunManager.set_lot() to compute LotStore's initial AP.
func draw_ap_from_reserve(deficit: int) -> int:
    if deficit <= 0 or _refill_metric <= 0:
        return 0
    var take: int = mini(deficit, _refill_metric)
    _refill_metric -= take
    return take


## Accumulates [param items] and [param price] from a won lot into the run-level
## totals. Called by RunManager.commit_lot_win() after LotStore records the win.
func accumulate_lot_result(items: Array[ItemEntry], price: int) -> void:
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
