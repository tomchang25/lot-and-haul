# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── Inspection bucket tables ──────────────────────────────────────────────────

# Shared across all items. Maps inspection_level to a resolution bucket:
# 0 = rough, 1 = mid, 2 = fine.
const CONDITION_THRESHOLDS: Array[float] = [0.0, 1.0, 2.0]

# Display names indexed by ItemData.Rarity enum value.
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# Per-rarity inspection threshold ladders. Each entry feeds _bucket_index.
# Add a new rarity by adding one entry here.
const RARITY_THRESHOLDS: Dictionary = {
    ItemData.Rarity.COMMON: [0.0, 1.0],
    ItemData.Rarity.UNCOMMON: [0.0, 1.0, 2.0],
    ItemData.Rarity.RARE: [0.0, 1.0, 2.0, 4.0],
    ItemData.Rarity.EPIC: [0.0, 1.0, 2.0, 4.0],
    ItemData.Rarity.LEGENDARY: [0.0, 1.0, 2.0, 4.0],
}

# Uniform maximum range spread, in multiplier units around 1.0.
const PRICE_MAX_SPREAD: float = 1.0

# Inspection-level head-start formula: INSPECTION_BASE + rank * INSPECTION_PER_RANK.
const INSPECTION_BASE: float = 0.75
const INSPECTION_PER_RANK: float = 0.25

# ── Research tuning knobs ─────────────────────────────────────────────────────

const STUDY_BASE_DELTA: float = 0.25

const REPAIR_BASE: float = 0.15
const REPAIR_POWER: float = 0.5
const REPAIR_MIN_STEP: float = 0.02

const UNLOCK_BASE_EFFORT: float = 1.0

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# How far the player has advanced the identity chain this run.
# 0 = base layer (always visible); max = identity_layers.size() - 1.
var layer_index: int = 0

var condition: float = 1.0

# Unified inspection progress for both condition resolution and rarity resolution.
# Bumped by inspection actions; mapped to discrete buckets via the tables below.
var inspection_level: float = 0.0

# Unique persistent ID assigned when this entry enters storage.
# -1 = not yet in storage. Assigned by SaveManager
# never assigned inside create() and never reassigned.
var id: int = -1

# Rolled once at creation in [-0.5, 0.5]. Biases the estimated range away from
# the true price at low inspection; its contribution scales to zero at max
# inspection so the range always converges on the true value.
var center_offset: float = 0.0

# Accumulated effort toward the current layer's unlock action. Reset on
# advance_layer(). Persisted because UNLOCK resets it on advance, so completion
# cannot be derived from layer_index alone.
var unlock_progress: float = 0.0

# ══ Computed properties ═══════════════════════════════════════════════════════

var display_name: String:
    get:
        var name: String = active_layer().display_name
        if is_at_final_layer() and not is_veiled():
            name = "%s ·" % name
        if id >= 0 and ResearchSlot.action_for_item(SaveManager.research_slots, id) != "":
            name += " ⚙"
        return name

# Condition label shown to the player, keyed off the current inspect bucket.
var condition_label: String:
    get:
        if is_veiled():
            return ""

        match get_condition_bucket():
            0:
                return "???"
            1:
                if condition < 0.3:
                    return "Poor"
                elif condition < 0.6:
                    return "Fair"
                elif condition < 0.8:
                    return "Good"
                else:
                    return "Excellent"
            2:
                return "%d%%" % int(condition * 100)
            _:
                return "?????????"

var condition_mult_label: String:
    get:
        if is_veiled():
            return "×?"
        match get_condition_bucket():
            0:
                return "×?"
            1:
                return "~×%.2f" % get_known_condition_multiplier()
            2:
                return "×%.2f" % get_condition_multiplier()
            _:
                push_warning("condition bucket out of range: %d" % get_condition_bucket())
                return "×?"

var potential_label: String:
    get:
        if is_veiled():
            return "Veiled"
        return get_potential_rating()


func is_condition_inspectable() -> bool:
    if is_veiled() or is_condition_resolved():
        return false

    if get_condition_bucket() == 1 and condition < 0.3:
        return false

    return true


func get_condition_multiplier() -> float:
    if condition <= 0.6:
        return remap(condition, 0.0, 0.6, 0.5, 1.0)
    elif condition <= 0.8:
        return remap(condition, 0.6, 0.8, 1.0, 2.0)
    else:
        return remap(condition, 0.8, 1.0, 2.0, 4.0)


# Returns the condition multiplier the player can infer from their current inspect bucket.
# bucket 0 → neutral 1.0 (unknown)
# bucket 1 → midpoint of the visible 4-band (Poor / Fair / Good / Excellent)
# bucket 2 → the precise true multiplier
func get_known_condition_multiplier() -> float:
    match get_condition_bucket():
        0:
            return 1.0
        1:
            if condition < 0.3:
                return 0.5
            elif condition < 0.6:
                return 1.0
            elif condition < 0.8:
                return 1.5
            else:
                return 3.0
        2:
            return get_condition_multiplier()
        _:
            return 0.0


# Rarity rating the player can see at the current inspection bucket.
# Non-final buckets show "<Common|Uncommon|Rare>+" ("at least this rarity").
# The final bucket shows the bare true rarity name.
func get_potential_rating() -> String:
    var thresholds: Array[float] = _rarity_thresholds()
    var bucket: int = get_rarity_bucket()
    if bucket >= thresholds.size() - 1:
        return _true_rarity_name()
    return "%s+" % RARITY_NAMES[bucket]

# ── Bucket helpers ────────────────────────────────────────────────────────────


func get_condition_bucket() -> int:
    return _bucket_index(inspection_level, CONDITION_THRESHOLDS)


func get_rarity_bucket() -> int:
    return _bucket_index(inspection_level, _rarity_thresholds())


func is_condition_resolved() -> bool:
    return get_condition_bucket() >= CONDITION_THRESHOLDS.size() - 1


func is_rarity_resolved() -> bool:
    return get_rarity_bucket() >= _rarity_thresholds().size() - 1


func is_fully_inspected() -> bool:
    return is_condition_resolved() and is_rarity_resolved()


func apply_inspect(delta: float) -> void:
    var max_threshold: float = _rarity_thresholds().back()
    var cap: float = maxf(max_threshold, CONDITION_THRESHOLDS.back())
    inspection_level = minf(cap, inspection_level + delta)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.INSPECT,
    )


func apply_study(speed_factor: float = 1.0) -> void:
    var delta: float = STUDY_BASE_DELTA * speed_factor
    var max_threshold: float = _rarity_thresholds().back()
    var cap: float = maxf(max_threshold, CONDITION_THRESHOLDS.back())
    inspection_level = minf(cap, inspection_level + delta)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.APPRAISE,
    )


func apply_repair(speed_factor: float = 1.0) -> void:
    var gap: float = 1.0 - condition
    var raw: float = REPAIR_BASE * speed_factor * pow(gap, REPAIR_POWER)
    var delta: float = maxf(raw, REPAIR_MIN_STEP * speed_factor)
    condition = minf(1.0, condition + delta)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.REPAIR,
    )


func add_unlock_effort(speed_factor: float = 1.0) -> void:
    var action: LayerUnlockAction = current_unlock_action()
    if action:
        unlock_progress = minf(action.difficulty, unlock_progress + UNLOCK_BASE_EFFORT * speed_factor)
    else:
        push_warning("ItemEntry: add_unlock_effort called with no unlock action available")


func advance_layer() -> void:
    layer_index += 1
    unlock_progress = 0.0
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.REVEAL,
    )


func is_repair_complete() -> bool:
    return condition >= 1.0


func is_unlock_ready() -> bool:
    if is_at_final_layer():
        return false
    var action: LayerUnlockAction = current_unlock_action()
    if action == null:
        return false
    return unlock_progress >= action.difficulty


var price_convergence_ratio: float:
    get:
        if PRICE_MAX_SPREAD == 0.0:
            return 1.0
        var thresholds: Array[float] = _rarity_thresholds()
        var max_threshold: float = thresholds[thresholds.size() - 1]
        if max_threshold <= 0.0:
            return 1.0
        return clampf(inspection_level / max_threshold, 0.0, 1.0)


func is_price_converged() -> bool:
    return price_convergence_ratio >= 1.0

var unlock_ratio: float:
    get:
        if is_at_final_layer():
            return 1.0
        var action: LayerUnlockAction = current_unlock_action()
        if action == null:
            return 1.0
        return clampf(unlock_progress / action.difficulty, 0.0, 1.0)


func _rarity_thresholds() -> Array[float]:
    var key: int = item_data.rarity
    if not RARITY_THRESHOLDS.has(key):
        push_warning("ItemEntry: unexpected rarity %d" % key)
        return [0.0]
    var result: Array[float] = []
    result.assign(RARITY_THRESHOLDS[key])
    return result


func _true_rarity_name() -> String:
    var r: int = item_data.rarity
    if r >= 0 and r < RARITY_NAMES.size():
        return RARITY_NAMES[r]
    return "?"


static func _bucket_index(level: float, thresholds: Array[float]) -> int:
    var idx: int = 0
    for i in range(thresholds.size()):
        if level >= thresholds[i]:
            idx = i
        else:
            break
    return idx


var estimated_value_min: int:
    get:
        if is_veiled():
            return 0
        return compute_price_range(ItemRegistry.price_config_with_estimated)[0]

var estimated_value_max: int:
    get:
        if is_veiled():
            return 0
        return compute_price_range(ItemRegistry.price_config_with_estimated)[1]

var estimated_value_label: String:
    get:
        if is_veiled():
            return "???"
        var suffix: String = "" if is_at_final_layer() else "+"
        var lo: int = estimated_value_min
        var hi: int = estimated_value_max
        if lo == hi:
            return "$%d%s" % [lo, suffix]
        return "$%d - $%d%s" % [lo, hi, suffix]


# Unified pricing pipeline. Reads the active layer's base value, then
# conditionally folds in condition, knowledge, and market factors based on the
# supplied PriceConfig, and finally scales by config.multiplier.
func compute_price(config: PriceConfig) -> int:
    var value: float = float(active_layer().base_value)

    if config.condition:
        if config.use_known_condition:
            value *= get_known_condition_multiplier()
        else:
            value *= get_condition_multiplier()

    if config.knowledge:
        var rank: int = KnowledgeManager.get_super_category_rank(
            item_data.category_data.super_category,
        )
        value *= 1.0 + 0.01 * rank

    if config.market:
        value *= MarketManager.get_category_factor(
            item_data.category_data.category_id,
        )

    value *= config.multiplier
    return int(value)


# Returns the estimated price range as [min, max] for the given config. The
# midpoint is compute_price(config); the spread widens with lower
# inspection_level and is biased by center_offset so identical items diverge
# until inspected. Both ends are clamped to a minimum of 1 so the UI never
# shows $0 or a negative price.
func compute_price_range(config: PriceConfig) -> Array[int]:
    var base: float = float(compute_price(config))
    var progress: float = price_convergence_ratio
    var spread: float = _max_spread() * (1.0 - progress)
    var offset: float = center_offset * (1.0 - progress)
    var range_min: float = 1.0 - spread + offset
    var range_max: float = 1.0 + spread + offset
    var result: Array[int] = []
    result.append(maxi(1, int(base * range_min)))
    result.append(maxi(1, int(base * range_max)))
    return result


func _max_spread() -> float:
    return PRICE_MAX_SPREAD


var market_price: int:
    get:
        return compute_price(ItemRegistry.price_config_with_market)

var market_factor_delta: float:
    get:
        return MarketManager.get_category_factor(
            item_data.category_data.category_id,
        ) - 1.0

# ── Display colors ────────────────────────────────────────────────────────────

## The tint to apply to the condition label, based on what the player knows.
## Unknown (veiled or bucket 0) → neutral grey. Known → banded by true condition.
var condition_color: Color:
    get:
        if is_veiled() or get_condition_bucket() == 0:
            return Color(0.5, 0.5, 0.5)
        if condition >= 0.8:
            return Color.GOLD
        elif condition >= 0.6:
            return Color.GREEN_YELLOW
        elif condition >= 0.3:
            return Color.WHITE
        else:
            return Color.LIGHT_CORAL

## Standard green used for any confirmed price / value label.
const PRICE_COLOR := Color(0.4, 1.0, 0.5)

## Grey used for unknown / placeholder price labels.
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

## Returns the correct color for price labels.
var price_color: Color:
    get:
        return PRICE_UNKNOWN_COLOR if is_veiled() else PRICE_COLOR

# ── Context-aware helpers ─────────────────────────────────────────────────────
# The price helpers below are the only display functions that still take a
# context, because they dispatch on stage (estimated / merchant / order).
# Condition and rarity displays live on the properties above.


# Bridge method — kept for ItemCard / ItemRowTooltip which dispatch on stage.
func price_label_for(ctx: ItemViewContext) -> String:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO, \
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return estimated_value_label
        ItemViewContext.Stage.MERCHANT_SHOP:
            return merchant_offer_label(ctx.merchant)
        ItemViewContext.Stage.FULFILLMENT_PANEL:
            return special_order_label(ctx.order)
        _:
            push_warning("Unknown Stage for price: %d" % ctx.stage)
            return estimated_value_label


# Bridge method — kept for ItemCard / ItemRowTooltip which dispatch on stage.
func price_value_for(ctx: ItemViewContext) -> int:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO, \
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return estimated_value_sort_value()
        ItemViewContext.Stage.MERCHANT_SHOP:
            return merchant_offer_value(ctx.merchant)
        ItemViewContext.Stage.FULFILLMENT_PANEL:
            return special_order_value(ctx.order)
        _:
            push_warning("Unknown Stage for price: %d" % ctx.stage)
            return 0

# ── Per-column price getters ─────────────────────────────────────────────────


func estimated_value_sort_value() -> int:
    return estimated_value_min


func base_value_label_text() -> String:
    return "???" if is_veiled() else "$%d" % active_layer().base_value


func base_value_sort_value() -> int:
    return 0 if is_veiled() else active_layer().base_value


func merchant_offer_label(merchant: MerchantData) -> String:
    return "$%d" % merchant_offer_value(merchant)


func merchant_offer_value(merchant: MerchantData) -> int:
    return merchant.offer_for(self) if merchant else market_price


func special_order_label(order: SpecialOrder) -> String:
    return "$%d" % special_order_value(order)


func special_order_value(order: SpecialOrder) -> int:
    return order.compute_item_price(self) if order else 0


# Returns the layer currently visible to the player.
func active_layer() -> IdentityLayer:
    return item_data.identity_layers[layer_index]


# Returns the unlock_action for advancing beyond the current layer.
# Null if already at the final layer.
func current_unlock_action() -> LayerUnlockAction:
    return item_data.identity_layers[layer_index].unlock_action


# True if the item is at the base layer — inspection was not performed.
func is_veiled() -> bool:
    return layer_index == 0


# True if no further layers exist.
func is_at_final_layer() -> bool:
    return layer_index == item_data.identity_layers.size() - 1


# Advances a veiled item (layer 0) to layer 1. Shared by the reveal scene, the
# X-Ray inspect action, and any other caller that needs to unveil an item
# mid-run. The inspection-driven range already handles price resolution; this
# function only moves the identity pointer.
func unveil() -> void:
    if not is_veiled():
        return
    layer_index = 1


func reveal() -> void:
    var rank: int = KnowledgeManager.get_super_category_rank(item_data.category_data.super_category)
    inspection_level = maxf(_rank_inspection_level(rank), inspection_level)


# Head-start inspection level granted by the player's category rank. Shared by
# create() (initial value) and reveal() (post-unveil floor).
static func _rank_inspection_level(rank: int) -> float:
    return INSPECTION_BASE + float(rank) * INSPECTION_PER_RANK

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData, veil_chance: float = 0.0) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()
    entry.center_offset = randf_range(-0.5, 0.5)

    # Layer 0 = veiled. If veil does not apply, auto-advance to layer 1.
    var start_veiled := randf() < veil_chance
    entry.layer_index = 0 if start_veiled else 1

    # Head start from category experience. Tunable — higher rank = more known.
    var rank: int = KnowledgeManager.get_super_category_rank(data.category_data.super_category)
    entry.inspection_level = _rank_inspection_level(rank)

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "layer_index": layer_index,
        "condition": condition,
        "inspection_level": inspection_level,
        "center_offset": center_offset,
        "unlock_progress": unlock_progress,
    }


static func from_dict(d: Dictionary) -> ItemEntry:
    var data: ItemData = ItemRegistry.get_item_by_id(d["item_id"])
    if data == null:
        push_error("ItemEntry: item not found for id '%s'" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = data
    entry.layer_index = int(d["layer_index"])
    entry.condition = float(d["condition"])
    entry.inspection_level = _read_inspection_level(d)
    if d.has("center_offset"):
        entry.center_offset = float(d["center_offset"])
    else:
        # Migrate pre-range saves: roll a fresh offset so old items behave like
        # new ones. Old knowledge_min/max are discarded.
        entry.center_offset = randf_range(-0.5, 0.5)
    if d.has("unlock_progress"):
        entry.unlock_progress = float(d["unlock_progress"])
    if d.has("id"):
        entry.id = int(d["id"])
    return entry


# Reads inspection_level from the save dict, migrating from the old schema
# (condition_inspect_level + potential_inspect_level as ints) when needed.
# Old → new mapping uses max(old_condition, old_potential): 0 → 0.0, 1 → 1.0, 2 → 4.0.
# The 2 → 4.0 mapping is deliberately generous so fully-inspected items land
# at the finest rarity bucket for every rarity threshold table.
static func _read_inspection_level(d: Dictionary) -> float:
    if d.has("inspection_level"):
        return float(d["inspection_level"])
    var old_cond: int = int(d.get("condition_inspect_level", 0))
    var old_pot: int = int(d.get("potential_inspect_level", 0))
    var old_max: int = maxi(old_cond, old_pot)
    match old_max:
        0:
            return 0.0
        1:
            return 1.0
        2:
            return 4.0
        _:
            return 0.0
