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

var price_variance: float = 1.0

# One entry per item in this lot. Generated from lot_data.item_pool at creation.
var item_entries: Array[ItemEntry] = []

# Cached NPC estimate rolled once at creation.
# Both get_opening_bid() and auction rolled_price derive from this value.
var npc_estimate: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


# Creates a LotEntry by rolling all factors from lot_data ranges
# and generating one ItemEntry per item in lot_data.item_pool.
# Apply external modifiers (player buffs, NPC presence) to the returned entry
# before passing it to RunRecord.create().
static func create(data: LotData) -> LotEntry:
    var entry := LotEntry.new()
    entry.lot_data = data

    entry.aggressive_factor = randf_range(data.aggressive_factor_min, data.aggressive_factor_max)
    entry.price_variance = randf_range(data.price_variance_min, data.price_variance_max)

    for item: ItemData in data.item_pool:
        entry.item_entries.append(ItemEntry.create(item, data.veiled_chance))

    # Cache after item_entries are populated — get_npc_estimate() reads them.
    entry.npc_estimate = entry.roll_npc_estimate()

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


# Returns the cached NPC estimate. Stable across calls.
func get_npc_estimate() -> int:
    return npc_estimate


# Opening bid shown in the pre-auction review and used as the auction starting price.
# Derived from npc_estimate so both blocks always agree.
func get_opening_bid() -> int:
    return roundi(get_npc_estimate() * lot_data.opening_bid_factor)


# Called once during create(). Rolls randf() per item — never call again after caching.
func roll_npc_estimate() -> int:
    var total := 0
    for entry: ItemEntry in item_entries:
        if entry.item_data.identity_layers.is_empty():
            continue

        var base_layer := entry.layer_index
        while base_layer < entry.item_data.identity_layers.size() - 1 and randf() < lot_data.npc_layer_sight_chance ** (entry.layer_index + 1):
            base_layer += 1
        total += entry.item_data.identity_layers[base_layer].base_value

    return total


func get_rolled_price() -> int:
    var aggressive_lerp := lerpf(
        lot_data.aggressive_lerp_min,
        lot_data.aggressive_lerp_max,
        aggressive_factor,
    )
    var raw: float = npc_estimate * aggressive_lerp * price_variance
    var floor_val := npc_estimate * lot_data.price_floor_factor
    var ceil_val := npc_estimate * lot_data.price_ceiling_factor
    return roundi(clampf(raw, floor_val, ceil_val))
