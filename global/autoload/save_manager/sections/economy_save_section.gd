# economy_save_section.gd
# Save section: economy state — cash, per-category points, attribute levels,
# and unlocked perks. Reads/writes the corresponding fields on the SaveManager
# singleton; registered with SaveManager as the "economy" section.
class_name EconomySaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "economy"


func to_dict() -> Dictionary:
    return {
        "cash": SaveManager.cash,
        "category_points": SaveManager.category_points,
        "attribute_levels": SaveManager.attribute_levels,
        "unlocked_perks": SaveManager.unlocked_perks,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("category_points") and data["category_points"] is Dictionary:
        SaveManager.category_points = data["category_points"]
    if data.has("cash") and data["cash"] is float:
        SaveManager.cash = int(data["cash"])
    if data.has("unlocked_perks") and data["unlocked_perks"] is Array:
        SaveManager.unlocked_perks = []
        for s: Variant in data["unlocked_perks"]:
            if s is String:
                SaveManager.unlocked_perks.append(s)
    if data.has("attribute_levels") and data["attribute_levels"] is Dictionary:
        SaveManager.attribute_levels = { }
        for key: Variant in data["attribute_levels"]:
            if key is String and data["attribute_levels"][key] is float:
                SaveManager.attribute_levels[key] = int(data["attribute_levels"][key])
    elif data.has("skill_levels"):
        # Migration: discard old skill_levels, start fresh with defaults.
        SaveManager.attribute_levels = { }
    else:
        SaveManager.attribute_levels = { }
