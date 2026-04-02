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

# ══ Estimates ═════════════════════════════════════════════════════════════════


# Sum of each item's active (player-discovered) layer base_value.
# Represents the player's current inspection knowledge of this lot.
func get_player_estimate() -> int:
    var total := 0
    for entry: ItemEntry in item_entries:
        if not entry.item_data.identity_layers.is_empty():
            total += entry.active_layer().base_value
    return total


# Sum of each item's layer 0 base_value.
# Represents the NPC's baseline valuation — used as the rolled_price anchor.
func get_npc_estimate() -> int:
    var total := 0
    for entry: ItemEntry in item_entries:
        if not entry.item_data.identity_layers.is_empty():
            if entry.is_veiled():
                total += entry.item_data.identity_layers[0].base_value
            else:
                var base_layer = 1
                while base_layer < entry.item_data.identity_layers.size() - 1 and randf() < 0.1:
                    base_layer += 1

                total += entry.item_data.identity_layers[base_layer].base_value
    return total


# Opening bid shown in the pre-auction review and used as the auction starting price.
# Derived from npc_estimate so both blocks always agree.
func get_opening_bid() -> int:
    return roundi(get_npc_estimate() * lot_data.opening_bid_factor)
