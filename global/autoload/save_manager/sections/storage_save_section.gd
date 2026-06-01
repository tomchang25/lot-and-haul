# storage_save_section.gd
# Save section: storage state — owned ItemEntry instances and the monotonic
# next_entry_id counter. Also carries the legacy research_slots migration (only
# present in pre-time-slot flat saves). Registered as the "storage" section.
class_name StorageSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "storage"


func to_dict() -> Dictionary:
    var serialized_items: Array = []
    for entry: ItemEntry in SaveManager.storage_items:
        serialized_items.append(entry.to_dict())
    return {
        "storage_items": serialized_items,
        "next_entry_id": SaveManager.next_entry_id,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("storage_items") and data["storage_items"] is Array:
        SaveManager.storage_items = []
        for d: Variant in data["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = ItemEntry.from_dict(d)
            if entry != null:
                entry.apply_storage_migration()
                SaveManager.storage_items.append(entry)
    if data.has("next_entry_id") and data["next_entry_id"] is float:
        SaveManager.next_entry_id = int(data["next_entry_id"])

    # ── Migration: discard legacy research_slots ──────────────────────────────
    # Old (pre-time-slot) flat saves carried a research_slots array. That array
    # is retired; partial research state is seeded into ItemEntry.research_progress
    # so no player work is lost. Absent from modern sectioned saves.
    if data.has("research_slots") and data["research_slots"] is Array:
        _migrate_research_slots(data["research_slots"])


## Converts legacy research_slots entries to ItemEntry.research_progress so
## in-flight research survives the save format change.
##
## REPAIR/RESTORE slots are discarded — condition is already on ItemEntry and
## persists unchanged. For RESEARCH slots with days_spent > 0, each day's
## equivalent progress (5 base, ignoring attribute) is added to the first
## unrevealed hidden clue in order.
func _migrate_research_slots(slots: Array) -> void:
    for d: Variant in slots:
        if not d is Dictionary:
            continue
        var action: String = d.get("action", "")
        if action != "research" and action != "authenticate":
            continue
        var item_id: int = int(d.get("item_id", -1))
        if item_id == -1:
            continue
        var days_spent: int = int(d.get("research_days_spent",
            d.get("authenticate_days_spent", 0)))
        if days_spent <= 0:
            continue
        var entry: ItemEntry = null
        for e: ItemEntry in SaveManager.storage_items:
            if e.id == item_id:
                entry = e
                break
        if entry == null or entry.verified:
            continue
        # Each legacy research day converts to 5 progress points (base rate,
        # no attribute — the pre-slot system had no attribute bonus for research).
        var remaining: int = days_spent * 5
        for clue: ClueData in entry.item_data.clues:
            if clue.type != ClueData.ClueType.HIDDEN:
                continue
            if entry.revealed_clue_ids.has(clue.clue_id):
                continue
            var existing: int = int(entry.research_progress.get(clue.clue_id, 0))
            if existing >= clue.dc:
                continue
            var needed: int = clue.dc - existing
            var apply: int = mini(remaining, needed)
            entry.research_progress[clue.clue_id] = existing + apply
            remaining -= apply
            if remaining <= 0:
                break
