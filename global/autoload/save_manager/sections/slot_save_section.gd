# slot_save_section.gd
# Save section: day-slot economy state — current slot, storage AP, committed
# selling slots, and pending run economics. Reads/writes the MetaManager
# singleton; registered with SaveManager as the "slot" section.
class_name SlotSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "slot"


func to_dict() -> Dictionary:
    return {
        "current_slot": MetaManager.current_slot,
        "storage_ap": MetaManager.storage_ap,
        "selling_slots_today": MetaManager.selling_slots_today,
        "pending_run": MetaManager.pending_run,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("current_slot") and data["current_slot"] is float:
        MetaManager.current_slot = int(data["current_slot"])
    if data.has("storage_ap") and data["storage_ap"] is float:
        MetaManager.storage_ap = int(data["storage_ap"])
    if data.has("selling_slots_today") and data["selling_slots_today"] is float:
        MetaManager.selling_slots_today = int(data["selling_slots_today"])

    # Pending run economics: intify on load (JSON numbers parse as float) so
    # end_day() reads plain ints. Absent/empty for saves with no run pending.
    MetaManager.pending_run = {}
    if data.has("pending_run") and data["pending_run"] is Dictionary:
        for key: Variant in data["pending_run"]:
            if key is String and data["pending_run"][key] is float:
                MetaManager.pending_run[key] = int(data["pending_run"][key])
