# progress_save_section.gd
# Save section: run-progression state — the current calendar day and the set of
# available locations. Locations are persisted by id and re-resolved through
# LocationRegistry on load. Registered as the "progress" section.
class_name ProgressSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "progress"


func to_dict() -> Dictionary:
    var available_location_ids: Array[String] = []
    for loc: LocationData in SaveManager.available_locations:
        available_location_ids.append(loc.location_id)
    return {
        "current_day": SaveManager.current_day,
        "available_location_ids": available_location_ids,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("current_day") and data["current_day"] is float:
        SaveManager.current_day = int(data["current_day"])
    if data.has("available_location_ids") and data["available_location_ids"] is Array:
        SaveManager.available_locations = []
        for id: Variant in data["available_location_ids"]:
            if not id is String:
                continue
            var loc: LocationData = LocationRegistry.get_location_by_id(id)
            if loc != null:
                SaveManager.available_locations.append(loc)
