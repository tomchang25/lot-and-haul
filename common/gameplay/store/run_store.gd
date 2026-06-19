# run_store.gd
# Session-scoped Store for a single warehouse run. Holds per-run cumulative and
# configuration state. Created and owned by RunManager for the duration of a run
# null between runs. Serialized as part of the run_snapshot save section.
#
# Per-lot mutable state (active entry, AP, win result) lives in LotStore.
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name RunStore
extends StoreBase

# ── Resume target constants ─────────────────────────────────────────────────────

const RESUME_LOCATION_ENTRY := "location_entry"
const RESUME_LOT_BROWSE := "lot_browse"
const RESUME_INSPECTION := "inspection"
const RESUME_REVEAL := "reveal"
const RESUME_CARGO := "cargo"
const RESUME_RUN_REVIEW := "run_review"


## Returns true when [param target] is one of the supported run resume scenes.
static func is_valid_resume_target(target: String) -> bool:
    match target:
        RESUME_LOCATION_ENTRY, RESUME_LOT_BROWSE, RESUME_INSPECTION, RESUME_REVEAL, RESUME_CARGO, RESUME_RUN_REVIEW:
            return true
        _:
            return false

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

var _resume_target: String = ""
var _trailer_damage_applied: bool = false

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

var resume_target: String:
    get:
        return _resume_target

var trailer_damage_applied: bool:
    get:
        return _trailer_damage_applied

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


## Sets the resume target for phase-scene restoration. Called by RunManager
## wrappers at each phase transition before saving.
func set_resume_target(target: String) -> void:
    _resume_target = target


## Applies trailer damage once to this run's trailer items. Returns the number
## of cracked items. Owns both the item mutation and idempotency flag so the
## run snapshot cannot persist one without the other.
func apply_trailer_damage() -> int:
    if _trailer_damage_applied:
        return 0
    if _car_data == null or _car_data.trailer_damage_chance <= 0.0:
        return 0

    var cracked := 0
    for entry: ItemEntry in _trailer_items:
        if RandomUtils.randf() < _car_data.trailer_damage_chance:
            var ratio := RandomUtils.randf_range(
                _car_data.trailer_damage_ratio_min,
                _car_data.trailer_damage_ratio_max,
            )
            entry.apply_damage(ratio)
            cracked += 1
    _trailer_damage_applied = true
    return cracked

# ══ Serialization ═════════════════════════════════════════════════════════════


## Encodes local scalar fields into a dictionary for the run snapshot. The caller
## (encode_snapshot) appends item-key arrays on top.
func _encode_fields() -> Dictionary:
    return {
        "_version": _store_version(),
        "trailer_damage_applied": _trailer_damage_applied,
        "location_id": _location_data.location_id if _location_data != null else "",
        "car_id": _car_data.car_id if _car_data != null else "",
        "inspection_ap_cap": _inspection_ap_cap,
        "refill_metric": _refill_metric,
        "entry_fee": _entry_fee,
        "fuel_cost": _fuel_cost,
        "stamina": _stamina,
        "max_stamina": _max_stamina,
        "paid_price": _paid_price,
        "onsite_proceeds": _onsite_proceeds,
        "browse_index": _browse_index,
        "browse_lot_ids": [],
    }


## Restores local scalar fields from [param data]. Returns false when any
## referenced designer resource cannot be resolved.
func _restore_fields(data: Dictionary, ctx: SaveLoadContext) -> bool:
    _trailer_damage_applied = bool(data.get("trailer_damage_applied", false))

    var loc_id: String = str(data.get("location_id", ""))
    _location_data = LocationRegistry.get_location_by_id(loc_id) if not loc_id.is_empty() else null
    if _location_data == null:
        ctx.info("Run location '%s' not found" % loc_id)
        return false

    var car_id: String = str(data.get("car_id", ""))
    _car_data = CarRegistry.get_car_by_id(car_id) if not car_id.is_empty() else null
    if _car_data == null:
        ctx.info("Run car '%s' not found" % car_id)
        return false

    _inspection_ap_cap = int(data.get("inspection_ap_cap", Economy.INSPECTION_AP_CAP))
    _refill_metric = int(data.get("refill_metric", Economy.INSPECTION_REFILL_METRIC_DEFAULT))
    _entry_fee = int(data.get("entry_fee", 0))
    _fuel_cost = int(data.get("fuel_cost", 0))
    _stamina = int(data.get("stamina", _max_stamina))
    _max_stamina = int(data.get("max_stamina", _stamina))
    _paid_price = int(data.get("paid_price", 0))
    _onsite_proceeds = int(data.get("onsite_proceeds", 0))
    _browse_index = int(data.get("browse_index", 0))

    _browse_lots.clear()
    for lot_id: Variant in data.get("browse_lot_ids", []):
        var lid: String = str(lot_id)
        var found := false
        for lot: LotData in _location_data.lot_pool:
            if lot.lot_id == lid:
                _browse_lots.append(lot)
                found = true
                break
        if not found:
            ctx.info("Browse lot '%s' not found in '%s' pool" % [lid, loc_id])
            return false

    if _browse_index < 0 or _browse_index > _browse_lots.size():
        ctx.info("Browse index %d is out of range for %d lot(s)" % [_browse_index, _browse_lots.size()])
        return false

    return true


## Encodes this run into the owning run snapshot. Item collections are stored as
## indexes into [param snapshot_ctx] so object identity survives restore.
func encode_snapshot(snapshot_ctx: RefCounted) -> Dictionary:
    var run_snapshot_ctx := snapshot_ctx as RunSnapshotContext
    if run_snapshot_ctx == null:
        ToastManager.show_dev_error("RunStore.encode_snapshot requires RunSnapshotContext")
        return _encode_fields()
    var d := _encode_fields()
    for lot: LotData in _browse_lots:
        d["browse_lot_ids"].append(lot.lot_id)
    d["won_item_keys"] = run_snapshot_ctx.item_keys_for(_won_items)
    d["cargo_item_keys"] = run_snapshot_ctx.item_keys_for(_cargo_items)
    d["trailer_item_keys"] = run_snapshot_ctx.item_keys_for(_trailer_items)
    return d


## Restores this run from the owning run snapshot. Returns false when any
## referenced designer data or item key cannot be resolved.
func restore_snapshot(data: Dictionary, snapshot_ctx: RefCounted, ctx: SaveLoadContext) -> bool:
    var run_snapshot_ctx := snapshot_ctx as RunSnapshotContext
    if run_snapshot_ctx == null:
        ctx.info("RunStore restore requires RunSnapshotContext")
        return false
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, ctx)

    if not _restore_fields(data, ctx):
        return false
    if not run_snapshot_ctx.restore_item_refs_into(_won_items, data.get("won_item_keys", []), ctx, "won_items"):
        return false
    if not run_snapshot_ctx.restore_item_refs_into(_cargo_items, data.get("cargo_item_keys", []), ctx, "cargo_items"):
        return false
    if not run_snapshot_ctx.restore_item_refs_into(_trailer_items, data.get("trailer_item_keys", []), ctx, "trailer_items"):
        return false

    return true


func _store_version() -> int:
    return 1
