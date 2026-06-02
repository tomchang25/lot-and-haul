# economy_save_section.gd
# Save section: economy state — cash. Reads/writes the MetaManager singleton;
# registered with SaveManager as the "economy" section.
class_name EconomySaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "economy"


func to_dict() -> Dictionary:
    return {"cash": MetaManager.cash}


func from_dict(data: Dictionary) -> void:
    if data.has("cash") and data["cash"] is float:
        MetaManager.cash = int(data["cash"])
