# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# The veiled type shown when is_veiled is true.
var resolved_veiled_type: VeiledType = null

# How far the player has investigated this item.
# 0 veiled / 1 untouched / 2 browsed / 3 examined / 4 researched / 5 authenticated
var inspection_level: int = 0

# ══ Computed properties ═══════════════════════════════════════════════════════


func is_veiled() -> bool:
    return inspection_level == 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData, veil_chance: float = 0.0) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    var is_veiled_bool := randf() < veil_chance and not data.veiled_types.is_empty()
    if is_veiled_bool:
        entry.resolved_veiled_type = data.veiled_types[randi() % data.veiled_types.size()]
    else:
        entry.inspection_level = 1

    return entry
