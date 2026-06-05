# progress_store.gd
# Progress runtime store: calendar day and sampled available locations.
# Serializable state slice held by MetaManager. Owns the fields, their save
# payload, and the operations that mutate them.
class_name ProgressStore
extends RefCounted

## Calendar day counter. Starts at 0, incremented by end_day().
var current_day: int = 0

## Currently available locations sampled for the run phase.
var available_locations: Array[LocationData] = []


## Increments current_day by one. Does not save.
func advance_day() -> void:
    current_day += 1


## Replaces available_locations with [param locations]. Does not save.
func set_locations(locations: Array[LocationData]) -> void:
    available_locations = locations


## Clears available_locations. Does not save.
func clear_locations() -> void:
    available_locations.clear()


## Section id for the progress save payload.
func section_id() -> String:
    return "progress"


## Serializes progress state to a save payload.
func to_dict() -> Dictionary:
    var available_location_ids: Array[String] = []
    for loc: LocationData in available_locations:
        available_location_ids.append(loc.location_id)
    return {
        "current_day": current_day,
        "available_location_ids": available_location_ids,
    }


## Restores progress state. Unresolved location ids are dropped with a warning.
func from_dict(data: Dictionary) -> void:
    if data.has("current_day") and data["current_day"] is float:
        current_day = int(data["current_day"])
    if data.has("available_location_ids") and data["available_location_ids"] is Array:
        available_locations = []
        for id_variant: Variant in data["available_location_ids"]:
            if not id_variant is String:
                continue
            var loc := LocationRegistry.get_location_by_id(id_variant as String)
            if loc == null:
                push_warning(
                    "ProgressStore: available_location_id '%s' not found — dropped" % id_variant,
                )
                continue
            available_locations.append(loc)


## Migrates stale fields within this section. Idempotent. No-op by default.
func migrate() -> void:
    pass


## Validates invariants within this section. Returns true when all pass.
func validate() -> bool:
    return true
