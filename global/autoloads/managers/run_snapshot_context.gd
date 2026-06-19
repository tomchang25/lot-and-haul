# run_snapshot_context.gd
# RunManager-owned run-snapshot context for preserving shared ItemEntry
# references across participating Store payloads. Owns the shared Entry table,
# serialization of table entries, and aggregate version migration.
class_name RunSnapshotContext
extends RefCounted

## Current aggregate snapshot version. Bump when the run_snapshot section shape
## changes irreversibly. Append a migrate_v1_to_v2 block when bumping.
const VERSION := 2

var _entries: Array[ItemEntry] = []
var _browse_lots_by_id: Dictionary = { }


## Returns the run-local item-table key for [param entry], appending it when it
## has not been encoded by another run collection yet.
func item_key_for(entry: ItemEntry) -> int:
    var index := _entries.find(entry)
    if index == -1:
        _entries.append(entry)
        index = _entries.size() - 1
    return index


## Converts [param entries] to run-local item-table keys while preserving shared
## ItemEntry identity across run and lot collections.
func item_keys_for(entries: Array[ItemEntry]) -> Array[int]:
    var keys: Array[int] = []
    for entry: ItemEntry in entries:
        keys.append(item_key_for(entry))
    return keys


## Serializes each unique run item exactly once. Collections in the snapshot
## reference entries by index. Returns a named table dict for forward compat
## with future entry types.
func encode_entries() -> Dictionary:
    var serialized: Array[Dictionary] = []
    for entry: ItemEntry in _entries:
        serialized.append(entry.to_dict())
    return { "items": serialized }


## Restores the run-local item table from [param raw_entries] (a dict like
## { "items": [...] }). Returns false on any missing referenced data so the
## whole run can be discarded atomically.
func restore_entries(raw_entries: Variant, ctx: SaveLoadContext) -> bool:
    if not (raw_entries is Dictionary):
        ctx.info("Run snapshot entries must be a dictionary")
        return false
    var raw_items: Variant = raw_entries.get("items", [])
    if not (raw_items is Array):
        ctx.info("Run entry table items is not an array")
        return false
    _entries.clear()
    for item_value: Variant in raw_items:
        if not (item_value is Dictionary):
            ctx.info("Run item table contains a non-dictionary entry")
            return false
        var item_dict: Dictionary = item_value
        var entry := ItemEntry.from_dict(item_dict, ctx)
        if entry == null:
            return false
        if not _entry_matches_saved_refs(entry, item_dict, ctx):
            return false
        _entries.append(entry)
    return true


## Restores [param target] from run-local item-table keys. Returns false when a
## key is invalid so the owning provider can discard the whole run snapshot.
func restore_item_refs_into(
        target: Array[ItemEntry],
        raw_keys: Variant,
        ctx: SaveLoadContext,
        label: String,
) -> bool:
    if not (raw_keys is Array):
        ctx.info("Run collection '%s' is not an array" % label)
        return false
    target.clear()
    for key_value: Variant in raw_keys:
        if not (key_value is float) and not (key_value is int):
            ctx.info("Run collection '%s' has invalid item key '%s'" % [label, key_value])
            return false
        var index := int(key_value)
        if index < 0 or index >= _entries.size():
            ctx.info("Run collection '%s' references missing item key %d" % [label, index])
            return false
        target.append(_entries[index])
    return true


## Binds the already-restored run browse pool so child Stores can resolve
## aggregate-local lot references without depending on RunStore directly.
func bind_browse_lots(browse_lots: Array[LotData]) -> void:
    _browse_lots_by_id.clear()
    for lot: LotData in browse_lots:
        if lot == null or lot.lot_id.is_empty():
            continue
        _browse_lots_by_id[lot.lot_id] = lot


## Resolves a lot id from the aggregate-local browse pool. Returns null and logs
## detail when the id cannot be resolved.
func resolve_browse_lot(lot_id: String, ctx: SaveLoadContext) -> LotData:
    if lot_id.is_empty():
        ctx.info("Active lot id is empty")
        return null
    var lot: LotData = _browse_lots_by_id.get(lot_id, null)
    if lot == null:
        ctx.info("Active lot '%s' not found in browse pool — lot not restored" % lot_id)
    return lot


## Migrates a legacy v1 run_snapshot payload (flat shape) to the current v2
## aggregate shape ({ _version, resume_target, entries: { items: [...] },
## stores: { run: {...}, lot?: {...} }}).
static func migrate_v1_to_v2(v1: Dictionary) -> Dictionary:
    var run_store_fields := { }
    for key in v1.keys():
        if key in ["items", "lot", "resume_target"]:
            continue
        run_store_fields[key] = v1[key]

    var out := {
        "_version": VERSION,
        "resume_target": v1.get("resume_target", ""),
        "entries": {
            "items": v1.get("items", []),
        },
        "stores": {
            "run": run_store_fields,
        },
    }
    if v1.has("lot"):
        out["stores"]["lot"] = v1["lot"]

    # Stamp VERSION for re-entry safety.
    out["_version"] = VERSION
    return out


## Verifies ItemEntry.from_dict() resolved every designer-resource reference
## that the run payload listed.
func _entry_matches_saved_refs(entry: ItemEntry, item_dict: Dictionary, ctx: SaveLoadContext) -> bool:
    var anchor_id: String = str(item_dict.get("anchor_id", ""))
    if anchor_id.is_empty() or entry.anchor == null:
        ctx.info("Run item anchor '%s' not found" % anchor_id)
        return false

    var category_id: String = str(item_dict.get("category_id", ""))
    if category_id.is_empty() or entry.category_data == null:
        ctx.info("Run item category '%s' not found" % category_id)
        return false

    var surface_value: Variant = item_dict.get("surface_ids", [])
    if not (surface_value is Array):
        ctx.info("Run item surface clue list is not an array")
        return false
    var surface_ids: Array = surface_value
    if entry.surface_clues.size() != surface_ids.size():
        ctx.info("Run item has missing surface clue data")
        return false

    var hidden_value: Variant = item_dict.get("hidden_ids", [])
    if not (hidden_value is Array):
        ctx.info("Run item hidden clue list is not an array")
        return false
    var hidden_ids: Array = hidden_value
    if entry.hidden_clues.size() != hidden_ids.size():
        ctx.info("Run item has missing hidden clue data")
        return false

    var affix_value: Variant = item_dict.get("affix_ids", [])
    if not (affix_value is Array):
        ctx.info("Run item affix list is not an array")
        return false
    var affix_ids: Array = affix_value
    if entry.affixes.size() != affix_ids.size():
        ctx.info("Run item has missing affix data")
        return false

    return true
