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

# Per-layer price bounds rolled once at lot draw.
# Index matches identity_layers; deeper layers have wider gaps.
var knowledge_min: Array[float] = []
var knowledge_max: Array[float] = []

# ══ Computed properties ═══════════════════════════════════════════════════════

var display_name: String:
    get:
        var name: String = active_layer().display_name
        if is_at_final_layer() and not is_veiled():
            return "%s ·" % name
        return name

# Raw condition label used by reveal and run review (true value, no inspect gate).
var condition_label: String:
    get:
        var cond_percent := int(condition * 100)

        return "%d%%" % [cond_percent]

var condition_mult_label: String:
    get:
        if is_veiled():
            return "×?"
        match get_condition_bucket():
            0:
                return "×?"
            1:
                return "~×0.50" if condition < 0.3 else "~×1.00"
            2:
                return "~×%.2f" % get_known_condition_multiplier()
            _:
                push_warning("condition bucket out of range: %d" % get_condition_bucket())
                return "×?"

var condition_inspect_label: String:
    get:
        if is_veiled():
            return ""

        match get_condition_bucket():
            0:
                return "???"
            1:
                return "Poor" if condition < 0.3 else "Common"
            2:
                if condition < 0.3:
                    return "Poor"
                elif condition < 0.6:
                    return "Fair"
                elif condition < 0.8:
                    return "Good"
                else:
                    return "Excellent"
            _:
                return "?????????"


func is_condition_inspectable() -> bool:
    if is_veiled() or is_condition_maxed():
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
# bucket 1 → midpoint of the visible band (Poor: 0.5, Common: 1.0)
# bucket 2 → true banded multiplier
func get_known_condition_multiplier() -> float:
    match get_condition_bucket():
        0:
            return 1.0
        1:
            return 0.5 if condition < 0.3 else 1.0
        2:
            if condition < 0.3:
                return 0.5
            elif condition < 0.6:
                return 1.0
            elif condition < 0.8:
                return 1.5
            else:
                return 3.0
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


func is_condition_maxed() -> bool:
    return get_condition_bucket() >= CONDITION_THRESHOLDS.size() - 1


func is_rarity_maxed() -> bool:
    return get_rarity_bucket() >= _rarity_thresholds().size() - 1


func _rarity_thresholds() -> Array[float]:
    match item_data.rarity:
        ItemData.Rarity.COMMON:
            return [0.0]
        ItemData.Rarity.UNCOMMON:
            return [0.0, 1.0]
        ItemData.Rarity.RARE:
            return [0.0, 1.0, 2.0, 4.0]
        ItemData.Rarity.EPIC:
            return [0.0, 1.0, 2.0, 4.0]
        ItemData.Rarity.LEGENDARY:
            return [0.0, 1.0, 2.0, 4.0]
        _:
            push_warning("ItemEntry: unexpected rarity %d" % item_data.rarity)
            return [0.0]


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
        var cond_mult: float = get_known_condition_multiplier()
        return int(active_layer().base_value * cond_mult * knowledge_min[layer_index])

var estimated_value_max: int:
    get:
        if is_veiled():
            return 0
        var cond_mult: float = get_known_condition_multiplier()
        return int(active_layer().base_value * cond_mult * knowledge_max[layer_index])

var estimated_value_label: String:
    get:
        if is_veiled():
            return "???"
        if estimated_value_min == estimated_value_max:
            return "$%d" % estimated_value_min
        return "$%d - $%d" % [estimated_value_min, estimated_value_max]

# Unified pricing pipeline. Reads the active layer's base value, then
# conditionally folds in condition, knowledge, and market factors based on the
# supplied PriceConfig, and finally scales by config.multiplier.
func compute_price(config: PriceConfig) -> int:
    var value: float = float(active_layer().base_value)

    if config.condition:
        value *= get_condition_multiplier()

    if config.knowledge:
        var rank: int = KnowledgeManager.get_super_category_rank(
            item_data.category_data.super_category.super_category_id,
        )
        value *= 1.0 + 0.01 * rank

    if config.market:
        value *= MarketManager.get_category_factor(
            item_data.category_data.category_id,
        )

    value *= config.multiplier
    return int(value)


var appraised_value: int:
    get:
        return compute_price(ItemRegistry.price_config_with_appraisal)

var market_price: int:
    get:
        return compute_price(ItemRegistry.price_config_with_market)

var market_factor_delta: float:
    get:
        return MarketManager.get_category_factor(
            item_data.category_data.category_id,
        ) - 1.0

var appraised_value_label: String:
    get:
        return "$%d" % appraised_value

# ── Display colors ────────────────────────────────────────────────────────────

## The tint to apply to any condition label, based on the true condition value.
## Use this in reveal, run review, or any "full truth" context.
var condition_color: Color:
    get:
        if condition >= 0.8:
            return Color.GOLD
        elif condition >= 0.6:
            return Color.GREEN_YELLOW
        elif condition >= 0.3:
            return Color.WHITE
        else:
            return Color.LIGHT_CORAL

## The tint to apply based on what the player *currently knows*.
## Unknown (bucket 0) → neutral grey. Known → same as condition_color.
var condition_inspect_color: Color:
    get:
        if is_veiled() or get_condition_bucket() == 0:
            return Color(0.5, 0.5, 0.5)
        return condition_color

## Standard green used for any confirmed price / value label.
const PRICE_COLOR := Color(0.4, 1.0, 0.5)

## Grey used for unknown / placeholder price labels.
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

## Returns the correct color for price labels.
var price_color: Color:
    get:
        return PRICE_UNKNOWN_COLOR if is_veiled() else PRICE_COLOR

# ── Context-aware helpers ─────────────────────────────────────────────────────
# These are the only display functions that ItemRow, ItemCard, and ItemRowTooltip
# call. No UI component branches on stage directly.


func condition_label_for(ctx: ItemViewContext) -> String:
    match ctx.condition_mode:
        ItemViewContext.ConditionMode.FORCE_TRUE_VALUE:
            return condition_label
        ItemViewContext.ConditionMode.FORCE_INSPECT_MAX:
            if condition < 0.3:
                return "Poor"
            elif condition < 0.6:
                return "Fair"
            elif condition < 0.8:
                return "Good"
            else:
                return "Excellent"
        ItemViewContext.ConditionMode.RESPECT_INSPECT_LEVEL:
            return condition_inspect_label
        _:
            push_warning("Unknown ConditionMode: %d" % ctx.condition_mode)
            return condition_inspect_label


func condition_color_for(ctx: ItemViewContext) -> Color:
    if ctx.condition_mode == ItemViewContext.ConditionMode.RESPECT_INSPECT_LEVEL:
        return condition_inspect_color
    return condition_color


func condition_mult_label_for(ctx: ItemViewContext) -> String:
    match ctx.condition_mode:
        ItemViewContext.ConditionMode.FORCE_TRUE_VALUE:
            return "×%.2f" % get_condition_multiplier()
        ItemViewContext.ConditionMode.FORCE_INSPECT_MAX:
            return condition_mult_label
        ItemViewContext.ConditionMode.RESPECT_INSPECT_LEVEL:
            return condition_mult_label
        _:
            push_warning("Unknown ConditionMode: %d" % ctx.condition_mode)
            return condition_mult_label


func potential_label_for(ctx: ItemViewContext) -> String:
    if is_veiled():
        return "Veiled"
    if ctx.potential_mode == ItemViewContext.PotentialMode.FORCE_FULL:
        return _true_rarity_name()
    return get_potential_rating()


# Bridge method — kept for ItemCard / ItemRowTooltip which dispatch on stage.
func price_label_for(ctx: ItemViewContext) -> String:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO:
            return estimated_value_label
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return appraised_value_label
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
        ItemViewContext.Stage.CARGO:
            return estimated_value_sort_value()
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return appraised_value
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
    return merchant.offer_for(self) if merchant else appraised_value


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


# Advances a veiled item (layer 0) to layer 1 and recalculates knowledge ranges
# at the new layer depth. Shared by the reveal scene, the X-Ray inspect action,
# and any other caller that needs to unveil an item mid-run.
# The recalculated ranges are only accepted if the total spread is tighter
# than the current ranges (same policy as KnowledgeManager.apply_market_research).
func unveil() -> void:
    if not is_veiled():
        return

    layer_index = 1

    var super_cat_id: String = item_data.category_data.super_category.super_category_id
    var layers_count: int = item_data.identity_layers.size()

    var old_range: float = 0.0
    for i in range(layers_count):
        old_range += knowledge_max[i] - knowledge_min[i]

    var new_min: Array[float] = []
    var new_max: Array[float] = []
    new_min.resize(layers_count)
    new_max.resize(layers_count)
    for i in range(layers_count):
        var depth: int = maxi(0, i - layer_index)
        var price_range: Vector2 = KnowledgeManager.get_price_range(
            super_cat_id,
            item_data.rarity,
            depth,
        )
        new_min[i] = price_range.x
        new_max[i] = price_range.y

    var new_range: float = 0.0
    for i in range(layers_count):
        new_range += new_max[i] - new_min[i]

    if new_range < old_range:
        knowledge_min = new_min
        knowledge_max = new_max

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData, veil_chance: float = 0.0) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()

    # Layer 0 = veiled. If veil does not apply, auto-advance to layer 1.
    var start_veiled := randf() < veil_chance
    entry.layer_index = 0 if start_veiled else 1

    var super_cat_id: String = data.category_data.super_category.super_category_id
    var layers_count: int = data.identity_layers.size()
    entry.knowledge_min.resize(layers_count)
    entry.knowledge_max.resize(layers_count)
    for i in range(layers_count):
        var depth: int = maxi(0, i - entry.layer_index)
        var price_range: Vector2 = KnowledgeManager.get_price_range(super_cat_id, data.rarity, depth)
        entry.knowledge_min[i] = price_range.x
        entry.knowledge_max[i] = price_range.y

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    var km: Array = []
    for v: float in knowledge_min:
        km.append(v)
    var kmax: Array = []
    for v: float in knowledge_max:
        kmax.append(v)
    return {
        "item_id": item_data.item_id,
        "id": id,
        "layer_index": layer_index,
        "condition": condition,
        "inspection_level": inspection_level,
        "knowledge_min": km,
        "knowledge_max": kmax,
    }


static func from_dict(d: Dictionary) -> ItemEntry:
    var data: ItemData = ItemRegistry.get_item(d["item_id"])
    if data == null:
        push_error("ItemEntry: item not found for id '%s'" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = data
    entry.layer_index = int(d["layer_index"])
    entry.condition = float(d["condition"])
    entry.inspection_level = _read_inspection_level(d)
    var km: Array = d["knowledge_min"]
    var kmax: Array = d["knowledge_max"]
    entry.knowledge_min.resize(km.size())
    entry.knowledge_max.resize(kmax.size())
    for i in range(km.size()):
        entry.knowledge_min[i] = float(km[i])
    for i in range(kmax.size()):
        entry.knowledge_max[i] = float(kmax[i])
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
