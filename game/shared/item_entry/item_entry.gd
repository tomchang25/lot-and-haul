# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# How far the player has advanced the identity chain this run.
# 0 = base layer (always visible); max = identity_layers.size() - 1.
var layer_index: int = 0

var condition: float = 1.0

var potential_inspect_level: int = 0

var condition_inspect_level: int = 0

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
        return active_layer().display_name

var level_label: String:
    get:
        return "???" if is_veiled() else "Level %d" % layer_index

# Raw condition label used by reveal and run review (true value, no inspect gate).
var condition_label: String:
    get:
        var cond_percent := int(condition * 100)

        return "%d%%" % [cond_percent]

var potential_inspect_label: String:
    get:
        if is_veiled():
            return "Veiled"
        match potential_inspect_level:
            0:
                return "? / ?"
            1, 2:
                var current := layer_index
                var max_layer := item_data.identity_layers.size() - 1
                return "Lv %d / %d  [%s]" % [current, max_layer, get_potential_rating()]
            _:
                push_warning("potential_inspect_level out of range: %d" % potential_inspect_level)
                return "? / ?"

var should_show_potential_price: bool:
    get:
        return not is_veiled() and potential_inspect_level >= 2

var condition_mult_label: String:
    get:
        if is_veiled():
            return "×?"
        match condition_inspect_level:
            0:
                return "×?"
            1:
                return "~×0.50" if condition < 0.3 else "~×1.00"
            2:
                return "~×%.2f" % get_known_condition_multiplier()
            _:
                push_warning("condition_inspect_level out of range: %d" % condition_inspect_level)
                return "×?"

var condition_inspect_label: String:
    get:
        if is_veiled():
            return ""

        match condition_inspect_level:
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
    if is_veiled() or condition_inspect_level >= 2:
        return false

    if condition_inspect_level == 1 and condition < 0.3:
        return false

    return true


func get_condition_multiplier() -> float:
    if condition <= 0.6:
        return remap(condition, 0.0, 0.6, 0.5, 1.0)
    elif condition <= 0.8:
        return remap(condition, 0.6, 0.8, 1.0, 2.0)
    else:
        return remap(condition, 0.8, 1.0, 2.0, 4.0)


# Returns the condition multiplier the player can infer from their current inspect level.
# level 0 → neutral 1.0 (unknown)
# level 1 → midpoint of the visible band (Poor: 0.75, Common: 1.5)
# level 2 → true multiplier
func get_known_condition_multiplier() -> float:
    match condition_inspect_level:
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
            return 0


func get_potential_rating() -> String:
    # Already at final layer — no upside
    if is_at_final_layer():
        return "Maxed"

    var current_val := active_layer().base_value
    if current_val <= 0:
        return "Probably Junk"

    # Find the best possible final layer value (upside ceiling)
    var best_val := 0
    for i in range(layer_index + 1, item_data.identity_layers.size()):
        var v := item_data.identity_layers[i].base_value
        if v > best_val:
            best_val = v

    var ratio := float(best_val) / float(current_val)
    if ratio >= 4.0:
        return "Potentially Valuable"
    elif ratio >= 1.5:
        return "Some Upside"
    else:
        return "Probably Junk"


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

var potential_price_min: int:
    get:
        if is_veiled() or knowledge_min.is_empty():
            return 0
        var cond_mult: float = get_known_condition_multiplier()
        var result: int = int(item_data.identity_layers[layer_index].base_value * knowledge_min[layer_index])
        for i in range(layer_index + 1, item_data.identity_layers.size()):
            var v: int = int(item_data.identity_layers[i].base_value * knowledge_min[i])
            if v < result:
                result = v
        return int(result * cond_mult)

var potential_price_max: int:
    get:
        if is_veiled() or knowledge_max.is_empty():
            return 0
        var cond_mult: float = get_known_condition_multiplier()
        var result: int = int(item_data.identity_layers[layer_index].base_value * knowledge_max[layer_index])
        for i in range(layer_index + 1, item_data.identity_layers.size()):
            var v: int = int(item_data.identity_layers[i].base_value * knowledge_max[i])
            if v > result:
                result = v
        return int(result * cond_mult)

var potential_price_label: String:
    get:
        if is_veiled():
            return "???"
        return "$%d - $%d" % [potential_price_min, potential_price_max]

var appraised_value: int:
    get:
        return int(
            active_layer().base_value
            * get_condition_multiplier()
            * (1.0 + 0.01 * KnowledgeManager.get_super_category_rank(
                    item_data.category_data.super_category.super_category_id,
                ) ),
        )

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
## Unknown (level 0) → neutral grey. Known → same as condition_color.
var condition_inspect_color: Color:
    get:
        if condition_inspect_level == 0 or is_veiled():
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
    if ctx.potential_mode == ItemViewContext.PotentialMode.FORCE_FULL:
        if is_veiled():
            return "Veiled"
        var current := layer_index
        var max_layer := item_data.identity_layers.size() - 1
        return "Lv %d / %d  [%s]" % [current, max_layer, get_potential_rating()]
    return potential_inspect_label


func should_show_potential_price_for(ctx: ItemViewContext) -> bool:
    if ctx.potential_mode == ItemViewContext.PotentialMode.FORCE_FULL:
        return not is_veiled()
    return should_show_potential_price


func price_label_for(ctx: ItemViewContext) -> String:
    match ctx.price_mode:
        ItemViewContext.PriceMode.APPRAISED_VALUE:
            return appraised_value_label
        ItemViewContext.PriceMode.BASE_VALUE:
            return "???" if is_veiled() else "$%d" % active_layer().base_value
        ItemViewContext.PriceMode.ESTIMATED_VALUE:
            return estimated_value_label
        ItemViewContext.PriceMode.MERCHANT_OFFER:
            return "$%d" % price_value_for(ctx)
        _:
            push_warning("Unknown PriceMode: %d" % ctx.price_mode)
            return estimated_value_label


func price_value_for(ctx: ItemViewContext) -> int:
    match ctx.price_mode:
        ItemViewContext.PriceMode.APPRAISED_VALUE:
            return appraised_value
        ItemViewContext.PriceMode.BASE_VALUE:
            return 0 if is_veiled() else active_layer().base_value
        ItemViewContext.PriceMode.ESTIMATED_VALUE:
            return estimated_value_min
        ItemViewContext.PriceMode.MERCHANT_OFFER:
            return ctx.merchant.offer_for(self) if ctx.merchant else appraised_value
        _:
            push_warning("Unknown PriceMode: %d" % ctx.price_mode)
            return 0


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
