# run_item_table.gd
# Run-snapshot identity table for preserving shared ItemEntry references.
class_name RunItemTable
extends RefCounted

var _entries: Array[ItemEntry] = []


## Returns the run-local item-table key for [param entry], appending it when it
## has not been encoded by another run collection yet.
func key_for(entry: ItemEntry) -> int:
    var index := _entries.find(entry)
    if index == -1:
        _entries.append(entry)
        index = _entries.size() - 1
    return index


## Converts [param entries] to run-local item-table keys while preserving shared
## ItemEntry identity across run and lot collections.
func keys_for(entries: Array[ItemEntry]) -> Array[int]:
    var keys: Array[int] = []
    for entry: ItemEntry in entries:
        keys.append(key_for(entry))
    return keys


## Serializes each unique run item exactly once. Collections in the snapshot
## reference entries by index into this table.
func encode_entries() -> Array[Dictionary]:
    var serialized: Array[Dictionary] = []
    for entry: ItemEntry in _entries:
        serialized.append(entry.to_dict())
    return serialized


## Restores the run-local item table. Returns false on any missing referenced
## data so the whole run can be discarded atomically.
func restore_entries(raw_items: Variant, ctx: SaveLoadContext) -> bool:
    if not (raw_items is Array):
        ctx.info("Run item table is not an array")
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
func restore_refs_into(
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
