# lot_entry.gd
# Runtime context for a single lot within a run.
# Rolls factor values from LotData ranges and generates ItemEntry instances.
# Created by warehouse_entry; consumed through the end of auction.
class_name LotEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

# Source data this entry was rolled from.
var lot_data: LotData = null

# Rolled from lot_data.aggressive_factor_range.
# Controls where NPCs estimate item value: 0.0 = low end, 1.0 = high end.
var aggressive_factor: float = 0.5

# Rolled from lot_data.demand_factor_range.
# Lerp weight between layer 0 base_value and player-discovered layer base_value.
var demand_factor: float = 0.5

# Rolled from lot_data.knowledge_factor_range. Placeholder — ignored until post-demo.
var knowledge_factor: float = 0.5

# One entry per item in this lot. Generated from lot_data.item_pool at creation.
var item_entries: Array[ItemEntry] = []

# ══ Factory ═══════════════════════════════════════════════════════════════════


# Creates a LotEntry by rolling all factors from lot_data ranges
# and generating one ItemEntry per item in lot_data.item_pool.
# Apply external modifiers (player buffs, NPC presence) to the returned entry
# before passing it to RunRecord.create().
static func create(data: LotData) -> LotEntry:
    var entry := LotEntry.new()
    entry.lot_data = data

    entry.aggressive_factor = randf_range(data.aggressive_factor_min, data.aggressive_factor_max)
    entry.demand_factor = randf_range(data.demand_factor_min, data.demand_factor_max)
    entry.knowledge_factor = randf_range(data.knowledge_factor_min, data.knowledge_factor_max)

    for item: ItemData in data.item_pool:
        entry.item_entries.append(ItemEntry.create(item))

    return entry
