# storage_store.gd
# Storage runtime store: owned ItemEntry instances and the monotonic
# next_entry_id counter. Serializable state slice held by MetaManager.
# Owns the fields and their save payload.
class_name StorageStore
extends StoreBase

## Array of ItemEntry instances the player currently owns in storage.
var storage_items: Array = []

## Monotonically increasing counter; never reset. Assigned to ItemEntry.id on
## registration so each entry has a unique id across the save's lifetime.
var next_entry_id: int = 0


## Registers a single [param entry]: assigns a stable id, appends to storage,
## and auto-reveals hidden clues when the item has auto_verify set.
## Does not save — callers commit via SaveManager.save().
func register_entry(entry: ItemEntry) -> void:
    entry.id = next_entry_id
    next_entry_id += 1
    storage_items.append(entry)
    if entry.item_data != null and entry.item_data.auto_verify:
        entry.reveal_all_hidden()


## Registers all entries in [param entries]. No save.
func register_entries(entries: Array) -> void:
    for e: ItemEntry in entries:
        register_entry(e)


## Removes each entry in [param entries] from storage. Returns an Array[int] of
## the ids that were removed. Does not save.
func remove_entries(entries: Array) -> Array:
    var ids: Array = []
    for e: ItemEntry in entries:
        ids.append(e.id)
        storage_items.erase(e)
    return ids


## Section id for the storage save payload.
func section_id() -> String:
    return "storage"


## Serializes storage state to a save payload.
func to_dict() -> Dictionary:
    var serialized_items: Array = []
    for entry: ItemEntry in storage_items:
        serialized_items.append(entry.to_dict())
    return {
        "storage_items": serialized_items,
        "next_entry_id": next_entry_id,
    }


## Restores storage state. ItemEntry instances for unknown item ids are dropped
## with a warning (push_warning in ItemEntry.from_dict). Includes migration for
## legacy research_slots saves.
func from_dict(data: Dictionary) -> void:
    if data.has("storage_items") and data["storage_items"] is Array:
        storage_items = []
        for d: Variant in data["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = ItemEntry.from_dict(d)
            if entry == null:
                continue
            entry.apply_storage_migration()
            storage_items.append(entry)
    if data.has("next_entry_id") and data["next_entry_id"] is float:
        next_entry_id = int(data["next_entry_id"])

    # ── Migration: discard legacy research_slots ──────────────────────────────
    # Old (pre-time-slot) flat saves carried a research_slots array. Absent from
    # modern sectioned saves.
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
        var days_spent: int = int(
            d.get(
                "research_days_spent",
                d.get("authenticate_days_spent", 0),
            ),
        )
        if days_spent <= 0:
            continue
        var entry: ItemEntry = null
        for e: ItemEntry in storage_items:
            if e.id == item_id:
                entry = e
                break
        if entry == null or entry.verified:
            continue
        # Each legacy research day converts to 5 progress points (base rate,
        # no attribute — the pre-slot system had no attribute bonus).
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
