# run_manager.gd
# Autoload: owns the active RunStore for the duration of a run.
# Null between runs. Provides the factory and AP resolution so no call site
# can forget to initialize these values.
extends Node

## Full state for the current run. Null between runs.
var run_store: RunStore = null


## Creates, initializes, assigns, and returns a new RunStore for [param location]
## and [param car]. Resolves auction AP at the single construction point so no
## caller can forget to initialize it. Called by Location Select before the run
## phase begins.
func create_run_store(location: LocationData, car: CarData) -> RunStore:
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
	run_store = r
	return r


## Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
	run_store = null

# ── Auction AP resolution ─────────────────────────────────────────────────────
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
