# lot_entry.gd
# Runtime context for a single lot within a run.
# Rolls factor values from LotData ranges and generates ItemEntry instances
# via the pool-based ItemGenerator. Created by location_entry; consumed through
# the end of auction.
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

# One entry per item in this lot. Generated from pool draws.
var item_entries: Array[ItemEntry] = []

# Cached NPC estimate rolled once at creation.
# Both get_opening_bid() and auction rolled_price derive from this value.
var npc_estimate: int = 0

# ══ Factory ═══════════════════════════════════════════════════════════════════


# Creates a LotEntry by rolling all factors from lot_data ranges
# and generating one ItemEntry per roll in lot_data.item_count_min/max
# using the pool-based ItemGenerator.
# [param rng] — optional seedable RNG for deterministic generation.
# When null, falls back to RandomUtils' shared production RNG.
# Apply external modifiers (player buffs, NPC presence) to the returned entry
# before passing it to RunManager.create_run_store().
static func create(data: LotData, rng: RandomNumberGenerator = null) -> LotEntry:
    var entry := LotEntry.new()
    entry.lot_data = data

    entry.aggressive_factor = RandomUtils.randf_range(
        data.aggressive_factor_min,
        data.aggressive_factor_max,
        rng,
    )

    entry.price_variance = RandomUtils.randf_range(
        data.price_variance_min,
        data.price_variance_max,
        rng,
    )

    var item_count := RandomUtils.randi_range(
        data.item_count_min,
        data.item_count_max,
        rng,
    )

    for i in range(item_count):
        var category := _draw_category(data, rng)
        if category == null:
            continue

        var rarity := _draw_rarity(data, rng)
        var item_entry := ItemGenerator.draw(
            category,
            data.tier_weights,
            rarity,
            rng,
        )
        if item_entry == null:
            ToastManager.show_dev_error(
                "LotEntry.create: ItemGenerator returned null for category '%s' (no eligible anchor?) — slot skipped"
                % category.category_id,
            )
            continue

        # Roll veiled_chance: each item independently starts pre-unveiled
        # when randf() > veiled_chance. Set unveiled directly —
        # no XP granted for system-level pre-unveils.
        if data.veiled_chance < 1.0 and RandomUtils.randf(rng) > data.veiled_chance:
            item_entry.unveiled = true
        entry.item_entries.append(item_entry)

    RandomUtils.shuffle(entry.item_entries, rng)

    # Cache after entries are populated — get_npc_estimate() reads them.
    entry.npc_estimate = entry.roll_npc_estimate(rng)

    return entry


# Rolls a category from the lot's weighted tables. Mirrors the original
# _draw_item_by_rarity_and_category category logic extracted into a helper.
# Returns null when no category can be resolved.
static func _draw_category(data: LotData, rng: RandomNumberGenerator = null) -> CategoryData:
    for attempt in range(MAX_ATTEMPTS):
        var category_id: String = ""
        if not data.super_category_weights.is_empty():
            # Roll super-category, then pick a member category uniformly.
            var sc_keys: Array = data.super_category_weights.keys()
            var sc_values: Array[int] = []
            for k in sc_keys:
                sc_values.append(data.super_category_weights[k])
            var sc_idx := RandomUtils.pick_weighted_index(sc_values, rng)
            if sc_idx < 0:
                ToastManager.show_warning("Super-category roll failed")
                return null
            var super_category_id: String = sc_keys[sc_idx]
            var sc_ref: SuperCategoryData = SuperCategoryRegistry.get_super_category_by_id(super_category_id)
            if sc_ref == null:
                continue
            var member_cats: Array[CategoryData] = SuperCategoryRegistry.get_categories_for_super(sc_ref)
            if member_cats.is_empty():
                continue
            category_id = member_cats[RandomUtils.randi(rng) % member_cats.size()].category_id
        else:
            var cat_keys: Array = data.category_weights.keys()
            var cat_values: Array[int] = []
            for k in cat_keys:
                cat_values.append(data.category_weights[k])
            var cat_idx := RandomUtils.pick_weighted_index(cat_values, rng)
            if cat_idx < 0:
                ToastManager.show_warning("Category roll failed")
                return null
            category_id = cat_keys[cat_idx]

        var cat := CategoryRegistry.get_category_by_id(category_id)
        if cat != null:
            return cat

    ToastManager.show_warning("_draw_category: no category found after %d attempts" % MAX_ATTEMPTS)
    return null


## Draws rarity from lot_data.rarity_weights, filtering to the three active
## tiers (COMMON, RARE, LEGENDARY). UNCOMMON and EPIC are frozen — their weights
## are ignored even if authored. Falls back to COMMON when all weights are zero.
static func _draw_rarity(data: LotData, rng: RandomNumberGenerator = null) -> Economy.Rarity:
    var active: Dictionary = { }
    for key: Variant in data.rarity_weights:
        var tier: int = int(key)
        if tier != Economy.Rarity.COMMON and tier != Economy.Rarity.RARE and tier != Economy.Rarity.LEGENDARY:
            continue
        if (data.rarity_weights[key] as int) > 0:
            active[tier] = data.rarity_weights[key]
    if active.is_empty():
        return Economy.Rarity.COMMON
    var keys: Array = active.keys()
    var values: Array[int] = []
    for k in keys:
        values.append(active[k])
    var idx := RandomUtils.pick_weighted_index(values, rng)
    if idx < 0:
        return Economy.Rarity.COMMON
    return int(keys[idx]) as Economy.Rarity


# Returns the cached NPC estimate. Stable across calls.
func get_npc_estimate() -> int:
    return npc_estimate


# Opening bid shown in the pre-auction review and used as the auction starting price.
# Derived from npc_estimate so both blocks always agree.
func get_opening_bid() -> int:
    return roundi(get_npc_estimate() * lot_data.opening_bid_factor)


# Called once during create(). Rolls randf() per item -- never call again after caching.
# [param rng] — optional seedable RNG for deterministic generation.
func roll_npc_estimate(rng: RandomNumberGenerator = null) -> int:
    var total := 0
    for entry: ItemEntry in item_entries:
        total += entry.roll_npc_estimate(lot_data.npc_clue_sight_chance, rng)
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


# Returns [total_min, total_max] based on player's current knowledge.
# Used by inspection review, auction summary, and storage display.
func get_player_estimate() -> Array[int]:
    var total_min := 0
    var total_max := 0

    for entry: ItemEntry in item_entries:
        if not entry.is_veiled():
            total_min += entry.estimated_value_min
            total_max += entry.estimated_value_max

    return [total_min, total_max]


# Returns a formatted price label string based on player's current knowledge.
func get_player_estimate_label(prefix: String = "Total Est:") -> String:
    var estimate := get_player_estimate()
    var total_min: int = estimate[0]
    var total_max: int = estimate[1]

    var has_veiled: bool = false
    for entry: ItemEntry in item_entries:
        if entry.is_veiled():
            has_veiled = true
            break

    var text: String
    if total_max <= total_min:
        text = "%s $%d" % [prefix, total_min]
    else:
        text = "%s $%d – $%d" % [prefix, total_min, total_max]
    if has_veiled:
        text += "+"
    return text
