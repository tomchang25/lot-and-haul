# slot_store.gd
# Slot-flow runtime store: current slot (Day/Night), storage AP, committed
# selling slots (legacy), and pending run economics. Serializable state slice
# held by MetaSystem.
# Owns the fields, their save payload, and the phase operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name SlotStore
extends StoreBase

## Two-slot Day/Night model constants.
const SLOT_DAY: int = 1
const SLOT_NIGHT: int = 2
## current_slot >= SLOT_DAY_ENDING triggers hub auto-end-day.
const SLOT_DAY_ENDING: int = 3

var _current_slot: int = SLOT_DAY
var _storage_ap: int = 0
var _storage_ap_max: int = 0
var _selling_slots_today: int = 0
var _pending_run: Dictionary = { }

## Current slot within the active day (1 = Day, 2 = Night, >= 3 = day-ending).
## Read-only externally.
var current_slot: int:
    get:
        return _current_slot

## AP remaining in the current storage slot. Read-only externally.
var storage_ap: int:
    get:
        return _storage_ap

## Maximum AP for the current storage slot. Read-only externally.
var storage_ap_max: int:
    get:
        return _storage_ap_max

## Legacy selling-slots counter preserved for save compatibility.
## No longer used to determine customer volume. Read-only externally.
var selling_slots_today: int:
    get:
        return _selling_slots_today

## Shallow duplicate of the pending-run economics dict. Read-only externally.
## Keys (all int): onsite_proceeds, paid_price, entry_fee, fuel_cost, cargo_count.
var pending_run: Dictionary:
    get:
        return _pending_run.duplicate()


## Sets current_slot to [param slot]. Does not save.
func set_slot(slot: int) -> void:
    _current_slot = slot


## Sets storage_ap and storage_ap_max to [param value]. Does not save.
func set_storage_ap(value: int) -> void:
    _storage_ap = value
    _storage_ap_max = value


## Sets selling_slots_today to [param value]. Does not save.
func set_selling_slots_today(value: int) -> void:
    _selling_slots_today = value


## Deducts [param cost] AP from the pool. Does not save. Called only after the
## effect lands — guards live in MetaSystem's public AP action methods.
func charge_ap(cost: int) -> void:
    _storage_ap -= cost


## Persists run economics from [param result] into pending_run so end_day can
## fold them into the day summary. Does not save.
func stash_pending_run(result: RunResult) -> void:
    _pending_run = {
        "onsite_proceeds": result.onsite_proceeds,
        "paid_price": result.paid_price,
        "entry_fee": result.entry_fee,
        "fuel_cost": result.fuel_cost,
        "cargo_count": result.cargo_items.size(),
    }


## Clears the pending run economics. Does not save.
func clear_pending_run() -> void:
    _pending_run = { }


## Section id for the slot save payload.
func section_id() -> String:
    return "slot"


## Returns current schema version. Version 2 remaps three-slot values to
## two-slot Day/Night equivalents.
func _store_version() -> int:
    return 2


## Serializes slot state to a save payload.
func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "current_slot": _current_slot,
        "storage_ap": _storage_ap,
        "storage_ap_max": _storage_ap_max,
        "selling_slots_today": _selling_slots_today,
        "pending_run": _pending_run,
    }


## Restores slot state. Unrecognised keys are silently ignored.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    _current_slot = int(data.get("current_slot", _current_slot))
    _storage_ap = int(data.get("storage_ap", _storage_ap))
    _storage_ap_max = int(data.get("storage_ap_max", _storage_ap_max))
    _selling_slots_today = int(data.get("selling_slots_today", _selling_slots_today))
    _pending_run = { }
    if data.has("pending_run") and data["pending_run"] is Dictionary:
        for key: Variant in data["pending_run"]:
            if key is String:
                _pending_run[key] = int(data["pending_run"][key])


## Migrates saved payloads from older schema versions.
## Version 2: remap three-slot values to two-slot:
##   Morning (1) → Day (1)
##   Afternoon (2) → Night (2)
##   Evening (3) → Night (2)
##   >=4 → day-ending (3)
func _apply_migrations(data: Dictionary, from_version: int, _ctx: SaveLoadContext) -> Dictionary:
    if from_version < 2:
        var old_slot: int = int(data.get("current_slot", SLOT_DAY))
        match old_slot:
            1:
                data["current_slot"] = SLOT_DAY
            2, 3:
                data["current_slot"] = SLOT_NIGHT
            _:
                data["current_slot"] = SLOT_DAY_ENDING
    data["_version"] = _store_version()
    return data
