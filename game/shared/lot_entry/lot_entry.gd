# lot_entry.gd
# Runtime context for a single lot within a run.
# Rolls factor values from LotData ranges and generates ItemEntry instances.
# Created by location_entry; consumed through the end of auction.
class_name LotEntry
extends RefCounted

const MAX_ATTEMPTS := 10

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

    var item_count := randi_range(data.item_count_min, data.item_count_max)

    for i in range(item_count):
        var item := _draw_item(data)

        if item != null:
            entry.item_entries.append(ItemEntry.create(item, data.veiled_chance))

    # Cache after item_entries are populated — get_npc_estimate() reads them.
    entry.npc_estimate = entry.roll_npc_estimate()

    return entry


# Rolls one item using rarity_weights then category, then picks a random
# matching item from ItemRegistry. Returns null if no match is found.
# If super_category_weights is non-empty, rolls a super-category first, then
# picks uniformly from its member categories. Falls through to category_weights.
static func _draw_item(data: LotData) -> ItemData:
    for attempt in range(MAX_ATTEMPTS):
        # Roll rarity
        var rarity_keys: Array = data.rarity_weights.keys()
        var rarity_values: Array[int] = []
        for k in rarity_keys:
            rarity_values.append(data.rarity_weights[k])
        var rarity_idx := RandomUtils.pick_weighted_index(rarity_values)
        if rarity_idx < 0:
            push_warning("Rarity roll failed")
            return null
        var rarity: ItemData.Rarity = rarity_keys[rarity_idx] as ItemData.Rarity

        # Roll category
        var category_id: String = ""
        if not data.super_category_weights.is_empty():
            # Roll super-category, then pick a member category uniformly.
            var sc_keys: Array = data.super_category_weights.keys()
            var sc_values: Array[int] = []
            for k in sc_keys:
                sc_values.append(data.super_category_weights[k])
            var sc_idx := RandomUtils.pick_weighted_index(sc_values)
            if sc_idx < 0:
                push_warning("Super-category roll failed")
                return null
            var super_category_id: String = sc_keys[sc_idx]
            var sc_ref: SuperCategoryData = SuperCategoryRegistry.get_super_category_by_id(super_category_id)
            if sc_ref == null:
                continue
            var member_cats: Array[CategoryData] = SuperCategoryRegistry.get_categories_for_super(sc_ref)
            if member_cats.is_empty():
                continue
            category_id = member_cats[randi() % member_cats.size()].category_id
        else:
            var cat_keys: Array = data.category_weights.keys()
            var cat_values: Array[int] = []
            for k in cat_keys:
                cat_values.append(data.category_weights[k])
            var cat_idx := RandomUtils.pick_weighted_index(cat_values)
            if cat_idx < 0:
                push_warning("Category roll failed")
                return null
            category_id = cat_keys[cat_idx]

        # Pick a random item matching both rarity and category
        var candidates: Array[ItemData] = ItemRegistry.get_items(rarity, category_id)
        if candidates.is_empty():
            continue
        return candidates[randi() % candidates.size()]

    push_warning("_draw_item: no candidates found after %d attempts" % MAX_ATTEMPTS)
    return null


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

        var npc_layer := entry.layer_index
        while npc_layer < entry.item_data.identity_layers.size() - 1 and randf() < lot_data.npc_layer_sight_chance ** (npc_layer - entry.layer_index + 1):
            npc_layer += 1
        total += entry.item_data.identity_layers[npc_layer].base_value

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
