# slot_store.gd
# Slot-flow runtime store: current slot, storage AP, committed selling slots,
# and pending run economics. Serializable state slice held by MetaManager.
# Owns the fields, their save payload, and the phase operations that mutate them.
class_name SlotStore
extends StoreBase

## Current slot index within the active day (1 = Morning, 2 = Afternoon,
## 3 = Evening). > 3 means the day is ending — hub auto-calls end_day on entry.
var current_slot: int = 1

## AP remaining in the current storage slot. Refreshed to Economy.STORAGE_AP_MAX
## at the start of each Storage slot; leftover is discarded when the slot ends.
var storage_ap: int = 0

## Selling slots committed to Open Shop this day.
var selling_slots_today: int = 0

## Run economics awaiting fold-in by end_day(). Populated by resolve_run() after
## an auction; consumed and cleared by end_day(). Empty when no run is pending.
## Keys (all int): onsite_proceeds, paid_price, entry_fee, fuel_cost, cargo_count.
var pending_run: Dictionary = { }


## Sets current_slot to [param slot]. Does not save.
func set_slot(slot: int) -> void:
    current_slot = slot


## Deducts [param cost] AP from the pool. Does not save. Called only after the
## effect lands — guards live in MetaManager's public AP action methods.
func charge_ap(cost: int) -> void:
    storage_ap -= cost


## Persists run economics from [param record] into pending_run so end_day can
## fold them into the day summary. Does not save.
func stash_pending_run(record: RunStore) -> void:
    pending_run = {
        "onsite_proceeds": record.onsite_proceeds,
        "paid_price": record.paid_price,
        "entry_fee": record.entry_fee,
        "fuel_cost": record.fuel_cost,
        "cargo_count": record.cargo_items.size(),
    }


## Clears the pending run economics. Does not save.
func clear_pending_run() -> void:
    pending_run = { }


## Section id for the slot save payload.
func section_id() -> String:
    return "slot"


## Serializes slot state to a save payload.
func to_dict() -> Dictionary:
    return {
        "current_slot": current_slot,
        "storage_ap": storage_ap,
        "selling_slots_today": selling_slots_today,
        "pending_run": pending_run,
    }


## Restores slot state. Unrecognised keys are silently ignored.
## pending_run values are intified (JSON numbers parse as float).
func from_dict(data: Dictionary) -> void:
    if data.has("current_slot") and data["current_slot"] is float:
        current_slot = int(data["current_slot"])
    if data.has("storage_ap") and data["storage_ap"] is float:
        storage_ap = int(data["storage_ap"])
    if data.has("selling_slots_today") and data["selling_slots_today"] is float:
        selling_slots_today = int(data["selling_slots_today"])
    pending_run = { }
    if data.has("pending_run") and data["pending_run"] is Dictionary:
        for key: Variant in data["pending_run"]:
            if key is String and data["pending_run"][key] is float:
                pending_run[key] = int(data["pending_run"][key])


