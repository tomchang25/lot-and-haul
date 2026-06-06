# run_manager.gd
# Autoload: owns the active RunStore for the duration of a run.
# Null between runs. Provides the factory, AP resolution, and run-phase
# mutation methods. Scenes read run state directly via RunManager.run.field.
extends Node

## Full state for the current run. Null between runs.
## Scenes in the run phase assert RunManager.is_run_active() on entry and then
## read directly: RunManager.run.won_items, RunManager.run.actions_remaining, etc.
## External code must never mutate RunStore fields directly — use RunManager's
## mutation methods below.
var run: RunStore = null


## Creates, initializes, and assigns a new RunStore for [param location] and
## [param car]. Resolves auction AP at the single construction point so no
## caller can forget to initialize it. Called by Location Select before the
## run phase begins.
func create_run_store(location: LocationData, car: CarData) -> void:
    var ap_cap := _resolve_inspection_ap_cap(car)
    var refill := _resolve_refill_reserve(car)
    var entry_fee := location.entry_fee if location != null else 0
    var fuel_cost := (
        car.fuel_cost_per_day * location.travel_days
        if location != null and car != null
        else 0
    )
    var r := RunStore.new()
    r.initialize(location, car, ap_cap, refill, entry_fee, fuel_cost)
    run = r


## Builds a RunResult snapshot from the active run: auto-reveals all surface
## clues on cargo items (the hub-return reveal), then copies economics and cargo
## into the returned value object. The caller (MetaManager.resolve_current_run)
## must call clear_run_state() after consuming the result.
## Asserts that a run is active — call only when is_run_active() is true.
func take_run_result() -> RunResult:
    assert(run != null, "take_run_result called with no active run")
    for entry: ItemEntry in run.cargo_items:
        entry.auto_reveal_all_surface()
    var result := RunResult.new()
    result.onsite_proceeds = run.onsite_proceeds
    result.paid_price = run.paid_price
    result.entry_fee = run.entry_fee
    result.fuel_cost = run.fuel_cost
    result.cargo_items.assign(run.cargo_items)
    return result


## Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
    run = null

# ── Run-state queries ──────────────────────────────────────────────────────────


## Returns true when a run is currently active (run is non-null).
func is_run_active() -> bool:
    return run != null

# ── Run-state mutations ────────────────────────────────────────────────────────


## Deducts [param cost] AP from the current lot's inspection pool.
func spend_ap(cost: int) -> void:
    if run:
        run.deduct_ap(cost)


## Records a won lot auction: stores [param items] as last_lot_won_items, adds
## [param price] to paid_price, and appends items to won_items. No-op when
## there is no active run.
func commit_lot_win(items: Array[ItemEntry], price: int) -> void:
    if run == null:
        return
    run.record_lot_win(items, price)


## Initialises browse state for a fresh location visit: assigns [param lots]
## and resets browse_index to 0. Called when LotBrowseScene first loads.
func init_browse_lots(lots: Array[LotData]) -> void:
    if run == null:
        return
    run.init_browse(lots)


## Advances browse_index by one (player passed or entered a lot).
func advance_browse_index() -> void:
    if run:
        run.advance_browse_index()


## Delegates to RunStore.set_lot, setting the active lot and refilling AP.
func set_lot(entry: LotEntry) -> void:
    if run:
        run.set_lot(entry)


## Commits cargo loading result: final [param cargo], [param trailer] items,
## and [param proceeds] from abandoned items sold on-site.
func commit_cargo(
        cargo: Array[ItemEntry],
        trailer: Array[ItemEntry],
        proceeds: int,
) -> void:
    if run == null:
        return
    run.set_cargo_result(cargo, trailer, proceeds)

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
