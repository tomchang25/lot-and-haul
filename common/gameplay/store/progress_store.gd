# progress_store.gd
# Progress runtime store: calendar day and sampled available locations.
# Serializable state slice held by MetaManager. Owns the fields, their save
# payload, and the operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name ProgressStore
extends StoreBase

var _current_day: int = 0
var _available_locations: Array[LocationData] = []

## Calendar day counter. Starts at 0, incremented by end_day(). Read-only externally.
var current_day: int:
    get:
        return _current_day

## Shallow duplicate of the available-locations list (LocationData refs shared).
## Read-only externally. Returns a duplicate for iteration stability.
var available_locations: Array[LocationData]:
    get:
        return _available_locations.duplicate()


## Increments current_day by one. Does not save.
func advance_day() -> void:
    _current_day += 1


## Replaces available_locations with [param locations]. Does not save.
func set_locations(locations: Array[LocationData]) -> void:
    _available_locations = locations


## Clears available_locations. Does not save.
func clear_locations() -> void:
    _available_locations.clear()


## Section id for the progress save payload.
func section_id() -> String:
    return "progress"


## Serializes progress state to a save payload.
func to_dict() -> Dictionary:
    var available_location_ids: Array[String] = []
    for loc: LocationData in _available_locations:
        available_location_ids.append(loc.location_id)
    return {
        "_version": _store_version(),
        "current_day": _current_day,
        "available_location_ids": available_location_ids,
    }


## Restores progress state. Unresolved location ids are dropped with a warning.
func from_dict(data: Dictionary) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version)
    if data.has("current_day") and data["current_day"] is float:
        _current_day = int(data["current_day"])
    if data.has("available_location_ids") and data["available_location_ids"] is Array:
        _available_locations = []
        for id_variant: Variant in data["available_location_ids"]:
            if not id_variant is String:
                continue
            var loc := LocationRegistry.get_location_by_id(id_variant as String)
            if loc == null:
                push_warning(
                    "ProgressStore: available_location_id '%s' not found — dropped" % id_variant,
                )
                continue
            _available_locations.append(loc)
