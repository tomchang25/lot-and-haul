# progress_save_section.gd
# Save section: run-progress state — calendar day and the currently available
# locations. Reads/writes the MetaManager singleton; registered with SaveManager
# as the "progress" section.
class_name ProgressSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "progress"


func to_dict() -> Dictionary:
    var available_location_ids: Array[String] = []
    for loc: LocationData in MetaManager.available_locations:
        available_location_ids.append(loc.location_id)
    return {
        "current_day": MetaManager.current_day,
        "available_location_ids": available_location_ids,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("current_day") and data["current_day"] is float:
        MetaManager.current_day = int(data["current_day"])
    if data.has("available_location_ids") and data["available_location_ids"] is Array:
        MetaManager.available_locations = []
        for id: Variant in data["available_location_ids"]:
            if not id is String:
                continue
            var loc: LocationData = LocationRegistry.get_location_by_id(id)
            if loc != null:
                MetaManager.available_locations.append(loc)
