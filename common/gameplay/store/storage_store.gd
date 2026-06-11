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


## Registers a single [param entry]: assigns a stable id and appends to storage.
## Items with zero hidden clues (COMMON rarity) are verified by default via the
## ItemEntry.verified getter — no explicit reveal needed.
## Does not save — callers commit via SaveManager.save().
func register_entry(entry: ItemEntry) -> void:
    entry.id = _next_entry_id
    _next_entry_id += 1
    _storage_items.append(entry)


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


## Restores storage state. apply_storage_migration() is called on each loaded
## entry to auto-reveal surface clues (not legacy — always runs).
## Counts dropped and degraded entries during restore; writes one summary line
## to [param ctx] via ctx.warn() when any loss occurs.
func from_dict(data: Dictionary, ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    var pre_migration_count := 0
    if data.has("storage_items") and data["storage_items"] is Array:
        pre_migration_count = data["storage_items"].size()
    data = _apply_migrations(data, version, ctx)
    var post_migration_count := 0
    if data.has("storage_items") and data["storage_items"] is Array:
        post_migration_count = data["storage_items"].size()
    var dropped_count := pre_migration_count - post_migration_count
    var degraded_count := 0
    if data.has("storage_items") and data["storage_items"] is Array:
        _storage_items = []
        for d: Variant in data["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = ItemEntry.from_dict(d, ctx)
            if entry == null:
                dropped_count += 1
                continue
            var listed_clues: int = d.get("surface_ids", []).size() + d.get("hidden_ids", []).size()
            var resolved_clues := entry.surface_clues.size() + entry.hidden_clues.size()
            if resolved_clues < listed_clues:
                degraded_count += 1
            entry.apply_storage_migration()
            _storage_items.append(entry)
        if dropped_count > 0 or degraded_count > 0:
            ctx.warn(
                "Storage: %d item(s) could not be restored, %d restored with missing data" % [dropped_count, degraded_count],
            )
    _next_entry_id = int(data.get("next_entry_id", _next_entry_id))


func _store_version() -> int:
    return 2


func _apply_migrations(data: Dictionary, from_version: int, ctx: SaveLoadContext) -> Dictionary:
    if from_version < 2:
        var migrated: Array = []
        for d: Variant in data.get("storage_items", []):
            if not d is Dictionary:
                migrated.append(d)
                continue
                # Legacy entry: has item_id but no anchor_id (pre-composition format).
                # ItemData and ItemRegistry no longer exist — items are composition-based
                # at runtime with no static item definitions to map old item_id values to.
                # Legacy entries are dropped with a warning (explicit data loss, rule §5).
                if d.has("item_id") and not d.has("anchor_id"):
                    ctx.info("StorageStore migration: item_id '%s' dropped — no ItemRegistry to resolve (composition-only)" % d["item_id"])
                    continue
            # Sniffing migrations — legacy keys written by pre-composition (v1) saves.
            var legacy_veiled := bool(d.get("anchor_revealed", false)) or bool(d.get("inspected", false))
            d["unveiled"] = bool(d.get("unveiled", false)) or legacy_veiled
            if bool(d.get("verified", false)):
                var revealed: Array = d.get("revealed_clue_ids", [])
                for cid: String in d.get("hidden_ids", []):
                    if not revealed.has(cid):
                        revealed.append(cid)
                d["revealed_clue_ids"] = revealed
            d.erase("anchor_revealed")
            d.erase("inspected")
            d.erase("verified")
            migrated.append(d)
        data["storage_items"] = migrated
        ctx.info("StorageStore: migrated to version 2 (item_id → composition)")
    return data
