# slot_store.gd
# Slot-flow runtime store: current slot, storage AP, committed selling slots,
# and pending run economics. Serializable state slice held by MetaManager.
# Owns the fields, their save payload, and the phase operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name SlotStore
extends StoreBase

var _current_slot: int = 1
var _storage_ap: int = 0
var _selling_slots_today: int = 0
var _pending_run: Dictionary = { }

## Current slot index within the active day (1 = Morning, 2 = Afternoon,
## 3 = Evening). > 3 means the day is ending — hub auto-calls end_day on entry.
## Read-only externally.
var current_slot: int:
    get:
        return _current_slot

## AP remaining in the current storage slot. Read-only externally.
var storage_ap: int:
    get:
        return _storage_ap

## Selling slots committed to Open Shop this day. Read-only externally.
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


## Sets storage_ap to [param value]. Does not save.
func set_storage_ap(value: int) -> void:
    _storage_ap = value


## Sets selling_slots_today to [param value]. Does not save.
func set_selling_slots_today(value: int) -> void:
    _selling_slots_today = value


## Deducts [param cost] AP from the pool. Does not save. Called only after the
## effect lands — guards live in MetaManager's public AP action methods.
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


## Serializes slot state to a save payload.
func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "current_slot": _current_slot,
        "storage_ap": _storage_ap,
        "selling_slots_today": _selling_slots_today,
        "pending_run": _pending_run,
    }


## Restores slot state. Unrecognised keys are silently ignored.
## pending_run values are intified (JSON numbers parse as float).
func from_dict(data: Dictionary) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version)
    if data.has("current_slot") and data["current_slot"] is float:
        _current_slot = int(data["current_slot"])
    if data.has("storage_ap") and data["storage_ap"] is float:
        _storage_ap = int(data["storage_ap"])
    if data.has("selling_slots_today") and data["selling_slots_today"] is float:
        _selling_slots_today = int(data["selling_slots_today"])
    _pending_run = { }
    if data.has("pending_run") and data["pending_run"] is Dictionary:
        for key: Variant in data["pending_run"]:
            if key is String and data["pending_run"][key] is float:
                _pending_run[key] = int(data["pending_run"][key])
