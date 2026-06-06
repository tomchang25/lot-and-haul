# run_manager.gd
# Autoload: owns the active RunStore for the duration of a run.
# Null between runs. Provides the factory, AP resolution, and a read-only proxy
# surface (mirroring MetaManager) so no scene touches RunStore directly.
extends Node

## Full state for the current run. Private — scenes use the proxy properties
## below; only manager-layer code (MetaManager.resolve_current_run) reads this.
var _run_store: RunStore = null

# ── Run-state proxy properties ─────────────────────────────────────────────────
# Read-only delegates — no setter means no external write path.
# Null-safe: return sensible defaults when _run_store is null (between runs).
# Reference-type collections return a shallow duplicate so callers cannot
# mutate live run state through the returned array.

var location_data: LocationData:
    get:
        return _run_store.location_data if _run_store else null

var car_data: CarData:
    get:
        return _run_store.car_data if _run_store else null

var lot_entry: LotEntry:
    get:
        return _run_store.lot_entry if _run_store else null

## Returns a shallow duplicate of the active lot's items (ItemEntry refs shared).
var lot_items: Array[ItemEntry]:
    get:
        return _run_store.lot_items.duplicate() if _run_store else []

## Returns a shallow duplicate of won items accumulated during the run.
var won_items: Array[ItemEntry]:
    get:
        return _run_store.won_items.duplicate() if _run_store else []

## Returns a shallow duplicate of the last lot's won items.
var last_lot_won_items: Array[ItemEntry]:
    get:
        return _run_store.last_lot_won_items.duplicate() if _run_store else []

## Returns a shallow duplicate of cargo items committed for transport.
var cargo_items: Array[ItemEntry]:
    get:
        return _run_store.cargo_items.duplicate() if _run_store else []

## Returns a shallow duplicate of trailer items committed for transport.
var trailer_items: Array[ItemEntry]:
    get:
        return _run_store.trailer_items.duplicate() if _run_store else []

var onsite_proceeds: int:
    get:
        return _run_store.onsite_proceeds if _run_store else 0

var paid_price: int:
    get:
        return _run_store.paid_price if _run_store else 0

var entry_fee: int:
    get:
        return _run_store.entry_fee if _run_store else 0

var fuel_cost: int:
    get:
        return _run_store.fuel_cost if _run_store else 0

var stamina: int:
    get:
        return _run_store.stamina if _run_store else 0

var actions_remaining: int:
    get:
        return _run_store.actions_remaining if _run_store else 0

var inspection_ap_cap: int:
    get:
        return _run_store.inspection_ap_cap if _run_store else 0

## Returns a shallow duplicate of the browse lot list.
var browse_lots: Array[LotData]:
    get:
        return _run_store.browse_lots.duplicate() if _run_store else []

var browse_index: int:
    get:
        return _run_store.browse_index if _run_store else 0


## Creates, initializes, and assigns a new RunStore for [param location] and
## [param car]. Resolves auction AP at the single construction point so no
## caller can forget to initialize it. Called by Location Select before the
## run phase begins.
func create_run_store(location: LocationData, car: CarData) -> void:
    var r := RunStore.new()
    r.location_data = location
    r.car_data = car
    r.max_stamina = car.stamina_cap
    r.stamina = r.max_stamina

    # Resolve auction AP at the single construction point so no caller can forget
    # to initialize it. Modifier sources fold into the resolvers below; the first
    # lot opens with a full pool.
    r.inspection_ap_cap = _resolve_inspection_ap_cap(car)
    r.refill_metric = _resolve_refill_reserve(car)
    r.actions_remaining = r.inspection_ap_cap

    _compute_travel_costs(r)
    _run_store = r


## Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
    _run_store = null

# ── Run-state queries ──────────────────────────────────────────────────────────


## Returns true when a run is currently active (_run_store is non-null).
func is_run_active() -> bool:
    return _run_store != null

# ── Run-state mutations ────────────────────────────────────────────────────────


## Deducts [param cost] AP from the current lot's inspection pool.
func spend_ap(cost: int) -> void:
    if _run_store:
        _run_store.actions_remaining -= cost


## Records a won lot auction: stores [param items] as last_lot_won_items, adds
## [param price] to paid_price, and appends items to won_items. No-op when
## there is no active run.
func commit_lot_win(items: Array[ItemEntry], price: int) -> void:
    if _run_store == null:
        return
    _run_store.last_lot_won_items = items.duplicate()
    _run_store.paid_price += price
    _run_store.won_items.append_array(items)


## Initialises browse state for a fresh location visit: assigns [param lots]
## and resets browse_index to 0. Called when LotBrowseScene first loads.
func init_browse_lots(lots: Array[LotData]) -> void:
    if _run_store == null:
        return
    _run_store.browse_lots = lots
    _run_store.browse_index = 0


## Advances browse_index by one (player passed or entered a lot).
func advance_browse_index() -> void:
    if _run_store:
        _run_store.browse_index += 1


## Delegates to RunStore.set_lot, setting the active lot and refilling AP.
func set_lot(entry: LotEntry) -> void:
    if _run_store:
        _run_store.set_lot(entry)


## Commits cargo loading result: final [param cargo], [param trailer] items,
## and [param proceeds] from abandoned items sold on-site.
func commit_cargo(
        cargo: Array[ItemEntry],
        trailer: Array[ItemEntry],
        proceeds: int,
) -> void:
    if _run_store == null:
        return
    _run_store.cargo_items = cargo
    _run_store.trailer_items = trailer
    _run_store.onsite_proceeds = proceeds

# ── Auction AP resolution ──────────────────────────────────────────────────────
# Single source of truth for a run's starting auction AP. Every modifier source
# (car, attributes, perks, …) folds in here, so all runs are built identically
# and no call site can bypass or forget one. Add new terms as the game grows —
# this is the only place auction AP should be computed.


## Resolves the per-lot inspection AP ceiling for a run using [param car].
@warning_ignore("unused_parameter")
func _resolve_inspection_ap_cap(car: CarData) -> int:
    var cap: int = Economy.INSPECTION_AP_CAP
    # Future modifiers fold in here, e.g.:
    #   cap += car.inspection_ap_bonus
    #   cap += KnowledgeManager.get_attribute_value("perception")
    return cap


## Resolves the inspection AP reserve (lot-boundary refill pool) using [param car].
@warning_ignore("unused_parameter")
func _resolve_refill_reserve(car: CarData) -> int:
    var reserve: int = Economy.INSPECTION_REFILL_METRIC_DEFAULT
    # Future modifiers fold in here.
    return reserve


## Computes travel costs (entry_fee, fuel_cost) on [param store] from its
## location_data and car_data. Called once at construction time.
func _compute_travel_costs(store: RunStore) -> void:
    store.entry_fee = store.location_data.entry_fee if store.location_data else 0
    store.fuel_cost = (
        store.car_data.fuel_cost_per_day * store.location_data.travel_days
        if store.location_data and store.car_data
        else 0
    )
