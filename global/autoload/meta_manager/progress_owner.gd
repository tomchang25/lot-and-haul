# progress_owner.gd
# Progress domain owner: calendar day and sampled available locations. Owns the
# fields and their save payload. Held by MetaManager; not a global singleton.
class_name ProgressOwner
extends RefCounted

## Calendar day counter. Starts at 0, incremented by end_day().
var current_day: int = 0

## Currently available locations sampled for the run phase.
var available_locations: Array[LocationData] = []


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
                    "ProgressOwner: available_location_id '%s' not found — dropped" % id_variant,
                )
                continue
            available_locations.append(loc)
