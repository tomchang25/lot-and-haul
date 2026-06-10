# storage_store.gd
# Storage runtime store: owned ItemEntry instances and the monotonic
# next_entry_id counter. Serializable state slice held by MetaManager.
# Owns the fields and their save payload.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name StorageStore
extends StoreBase

var _storage_items: Array = []
var _next_entry_id: int = 0

## Shallow duplicate of the storage array (ItemEntry refs shared). Read-only externally.
## Returns a duplicate for iteration stability; refs inside are shared.
var storage_items: Array:
    get:
        return _storage_items.duplicate()

## Monotonically increasing entry-id counter. Read-only externally.
var next_entry_id: int:
    get:
        return _next_entry_id


## Registers a single [param entry]: assigns a stable id, appends to storage,
## and auto-reveals hidden clues when the item has auto_verify set.
## Does not save — callers commit via SaveManager.save().
func register_entry(entry: ItemEntry) -> void:
    entry.id = _next_entry_id
    _next_entry_id += 1
    _storage_items.append(entry)
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
        _storage_items.erase(e)
    return ids


## Section id for the storage save payload.
func section_id() -> String:
    return "storage"


## Serializes storage state to a save payload.
func to_dict() -> Dictionary:
    var serialized_items: Array = []
    for entry: ItemEntry in _storage_items:
        serialized_items.append(entry.to_dict())
    return {
        "_version": _store_version(),
        "storage_items": serialized_items,
        "next_entry_id": _next_entry_id,
    }


## Restores storage state. ItemEntry instances for unknown item ids are dropped
## with a warning (push_warning in ItemEntry.from_dict). apply_storage_migration()
## is called on each loaded entry to auto-reveal surface clues (not legacy — always runs).
func from_dict(data: Dictionary) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version)
    if data.has("storage_items") and data["storage_items"] is Array:
        _storage_items = []
        for d: Variant in data["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = ItemEntry.from_dict(d)
            if entry == null:
                continue
            entry.apply_storage_migration()
            _storage_items.append(entry)
    _next_entry_id = int(data.get("next_entry_id", _next_entry_id))
