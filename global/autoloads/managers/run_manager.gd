# run_manager.gd
# Autoload: owns the active RunStore (per-run) and LotStore (per-lot) for the
# duration of a run. Both are null between runs. Provides the factory, AP
# resolution, and run-phase mutation methods. Scenes read run state via
# RunManager.run.field and lot state via RunManager.lot.field.
extends Node

## Full state for the current run. Null between runs.
## Scenes in the run phase should guard with RunManager.is_run_active() on entry and then
## read directly: RunManager.run.won_items, RunManager.run.inspection_ap_cap, etc.
## External code must never mutate RunStore fields directly — use RunManager's
## mutation methods below.
var run: RunStore = null

## State for the active lot visit. Null when no lot is loaded.
## Replaced by the next call to set_lot(); readable through the reveal phase.
## External code must never mutate LotStore fields directly.
var lot: LotStore = null


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
## Guards that a run is active — call only when is_run_active() is true.
func take_run_result() -> RunResult:
    if run == null:
        ToastManager.show_dev_error("take_run_result called with no active run")
        return RunResult.new()

    for entry: ItemEntry in run.cargo_items:
        entry.auto_reveal_all_surface()
    var result := RunResult.new()
    result.onsite_proceeds = run.onsite_proceeds
    result.paid_price = run.paid_price
    result.entry_fee = run.entry_fee
    result.fuel_cost = run.fuel_cost
    result.cargo_items.assign(run.cargo_items)
    return result


## Clears all per-run and per-lot state so the next run starts clean.
func clear_run_state() -> void:
    run = null
    lot = null

# ── Item mutation wrappers ─────────────────────────────────────────────────────
# Each wrapper calls the entry's mutator and emits the appropriate EventBus
# signal on success. Scenes go through these instead of mutating entries directly.


## Mediates a player-triggered unveil. Calls entry.unveil() (returns true when
## the flag actually flipped). On success and when the item has valid category
## data, emits item_unveiled so KnowledgeManager can award REVEAL XP.
func unveil_item(entry: ItemEntry) -> void:
    if entry.unveil() and entry.category_data != null:
        EventBus.item_unveiled.emit(entry)


## Mediates a clue-attempt roll. Looks up the attribute bonus for
## [param clue]'s attribute, calls entry.attempt_clue(), and emits
## item_revealed only when the revealed_clue_ids set grew (new clue revealed).
## Returns the roll result (succeeded) unchanged to the scene.
func attempt_clue(entry: ItemEntry, clue: ClueData) -> bool:
    var attr_value: int = KnowledgeManager.get_attribute_value(clue.attribute)
    var attribute_bonus: int = maxi(attr_value - 1, 0)
    var before := entry.revealed_clue_ids.size()
    var succeeded := entry.attempt_clue(clue, attribute_bonus)
    if entry.revealed_clue_ids.size() > before:
        EventBus.item_revealed.emit(entry)
    return succeeded


## Mediates bulk surface-clue auto-reveal. No signal — this is a hub-return
## reveal, not a player-triggered discovery.
func auto_reveal_all_surface(entry: ItemEntry) -> void:
    entry.auto_reveal_all_surface()


## Applies trailer damage to all trailer items in the active run. Rolls each
## item against [member CarData.trailer_damage_chance], applies a random ratio
## in [trailer_damage_ratio_min, trailer_damage_ratio_max], and returns the
## count of cracked items. Returns 0 when there is no active run or the car's
## damage chance is ≤ 0.0. Call from the run review scene before displaying rows.
func apply_trailer_damage() -> int:
    if run == null:
        return 0
    var car: CarData = run.car_data
    if car.trailer_damage_chance <= 0.0:
        return 0

    var cracked := 0
    for entry: ItemEntry in run.trailer_items:
        if RandomUtils.randf() < car.trailer_damage_chance:
            var ratio := RandomUtils.randf_range(car.trailer_damage_ratio_min, car.trailer_damage_ratio_max)
            entry.apply_damage(ratio)
            cracked += 1
    return cracked

# ── Run-state queries ──────────────────────────────────────────────────────────


## Returns true when a run is currently active (run is non-null).
func is_run_active() -> bool:
    return run != null

# ── Run-state mutations ────────────────────────────────────────────────────────


## Deducts [param cost] AP from the current lot's inspection pool.
func spend_ap(cost: int) -> void:
    if lot:
        lot.deduct_ap(cost)


## Records a won lot auction: writes the win to LotStore, then accumulates
## [param items] and [param price] into the run-level totals. No-op when there
## is no active run or lot.
func commit_lot_win(items: Array[ItemEntry], price: int) -> void:
    if run == null or lot == null:
        return
    lot.record_win(items, price)
    run.accumulate_lot_result(items, price)


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


## Creates a new LotStore for [param entry] with deficit-refilled AP, replacing
## any prior LotStore. AP handoff: (1) compute deficit below the cap from the
## prior lot's leftover AP, (2) draw that deficit from the run reserve,
## (3) construct LotStore with prior AP + drawn amount. First lot of a run
## receives the full cap (no reserve draw needed).
func set_lot(entry: LotEntry) -> void:
    if run == null:
        return
    var prior_ap: int = lot.actions_remaining if lot != null else run.inspection_ap_cap
    var deficit: int = run.inspection_ap_cap - prior_ap
    var drawn: int = run.draw_ap_from_reserve(deficit)
    var initial_ap: int = prior_ap + drawn
    var l := LotStore.new()
    l.initialize(entry, initial_ap)
    lot = l


## Nulls the active LotStore. Called by reveal_scene after reading results
## to release the per-lot state. (Superseded by the next set_lot() call in
## normal flow — explicit clear only needed if exiting without starting a new lot.)
func clear_lot() -> void:
    lot = null


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
