# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── Display constants ─────────────────────────────────────────────────────────

const UNKNOWN_TEXT := "???"

const COLUMN_NAME := 0
const COLUMN_CONDITION := 1
const COLUMN_ESTIMATED_VALUE := 2
const COLUMN_BASE_VALUE := 3
const COLUMN_MERCHANT_OFFER := 4
const COLUMN_SPECIAL_ORDER := 5
const COLUMN_RARITY := 6
const COLUMN_WEIGHT := 7
const COLUMN_GRID := 8
const COLUMN_MARKET_FACTOR := 9
const COLUMN_RESEARCH_STATUS := 10
const COLUMN_INSPECTION := 11

# ── Inspection constants ─────────────────────────────────────────────────────

# Condition display thresholds against inspection_level (0–1).
const CONDITION_THRESHOLDS: Array[float] = [0.0, 0.33, 0.66]

# Display names indexed by ItemData.Rarity enum value.
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# ── Research tuning knobs (non-inspection) ───────────────────────────────────

const REPAIR_BASE: float = 0.15
const REPAIR_ZONE_FACTORS: Dictionary = { 0.25: 1.0, 0.50: 0.35 }
const REPAIR_RARITY_FACTOR: Dictionary = {
    ItemData.Rarity.COMMON: 1.0,
    ItemData.Rarity.UNCOMMON: 0.9,
    ItemData.Rarity.RARE: 0.8,
    ItemData.Rarity.EPIC: 0.7,
    ItemData.Rarity.LEGENDARY: 0.6,
}

const RESTORE_BASE: float = 0.10
const RESTORE_ZONE_FACTORS: Dictionary = { 0.75: 0.12, 1.0: 0.02 }
const RESTORE_RARITY_FACTOR: Dictionary = {
    ItemData.Rarity.COMMON: 1.0,
    ItemData.Rarity.UNCOMMON: 0.8,
    ItemData.Rarity.RARE: 0.6,
    ItemData.Rarity.EPIC: 0.4,
    ItemData.Rarity.LEGENDARY: 0.2,
}
const RESTORE_SKILL_COEFF: float = 0.4
const RESTORE_CAT_SKILL_COEFF: float = 0.5

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# How far the player has advanced the identity chain this run.
# Runtime entries start at layer 1 while legacy YAML still carries a layer-0
# veil. Phase 0 keeps that data but uses inspected to gate visibility.
var layer_index: int = 1

# False until the player has inspected/revealed this entry.
var inspected: bool = false

var condition: float = 1.0

# Unique persistent ID assigned when this entry enters storage.
# -1 = not yet in storage. Assigned by SaveManager
# never assigned inside create() and never reassigned.
var id: int = -1

# Rolled once at creation in [-0.5, 0.5]. Biases the estimated range away from
# the true price at low inspection; its contribution scales to zero at max
# inspection so the range always converges on the true value.
var center_offset: float = 0.0

# True after Storage Authenticate completes. Reveals item_data.item_name
# and item_data.base_price in the UI.
var verified: bool = false

var revealed_clue_ids: Array[String] = []

# ══ Computed properties ═══════════════════════════════════════════════════════

# inspection_level is fully computed from layer_index relative to total layers.
# Veiled items return 0.0. Items with ≤2 layers are fully inspected once revealed.
# For ≥3 layers: 0.0 at layer 1, 1.0 at the final layer, linear in between.
var inspection_level: float:
    get:
        if not inspected:
            return 0.0
        if item_data == null or item_data.identity_layers.is_empty():
            return 1.0
        var total := item_data.identity_layers.size()
        if total <= 2:
            return 1.0
        var current := _safe_layer_index()
        return clampf(float(current - 1) / float(total - 2), 0.0, 1.0)

var display_name: String:
    get:
        if is_veiled():
            return "Unknown Item"
        if verified:
            if item_data.item_name.is_empty():
                push_warning("ItemEntry %d: verified but item_name is empty" % id)
                return "Unknown ✓"
            return "%s ✓" % item_data.item_name
        var name: String = active_layer().display_name
        if id >= 0 and ResearchSlot.action_for_item(SaveManager.research_slots, id) != "":
            name += " ⚙"
        return name

# Condition text getters live as functions below (condition_text() /
# condition_secondary_text()). They were previously also exposed as same-named
# computed properties — removed to eliminate name shadowing.


func get_condition_multiplier() -> float:
    if condition <= 0.25:
        return remap(condition, 0.0, 0.25, 0.25, 0.5)
    elif condition <= 0.5:
        return remap(condition, 0.25, 0.5, 0.5, 1.0)
    elif condition <= 0.75:
        return remap(condition, 0.5, 0.75, 1.0, 2.0)
    else:
        return remap(condition, 0.75, 1.0, 2.0, 4.0)


# Returns the condition multiplier the player can infer from their current inspect bucket.
# bucket 0 → neutral 1.0 (unknown)
# bucket 1 → midpoint of the visible 2-band (Poor / Good)
# bucket 2 → the precise true multiplier
func get_known_condition_multiplier() -> float:
    match get_condition_bucket():
        0:
            return 1.0
        1:
            if condition < 0.5:
                # Poor band midpoint: condition ~0.25 → multiplier ~0.5
                return 0.5
            else:
                # Good band midpoint: condition ~0.75 → multiplier ~2.0
                return 2.0
        2:
            return get_condition_multiplier()
        _:
            push_warning("Unknown condition bucket: %d" % get_condition_bucket())
            return 1.0

# ── Bucket helpers ────────────────────────────────────────────────────────────


func get_condition_bucket() -> int:
    return _bucket_index(inspection_level, CONDITION_THRESHOLDS)


func is_fully_inspected() -> bool:
    return inspection_level >= 1.0


func apply_repair() -> void:
    var zone_factor: float = REPAIR_ZONE_FACTORS[0.50]
    if condition < 0.25:
        zone_factor = REPAIR_ZONE_FACTORS[0.25]
    var rarity_factor: float = REPAIR_RARITY_FACTOR[item_data.rarity]
    var delta: float = REPAIR_BASE * zone_factor * rarity_factor
    condition = minf(condition + delta, 0.5)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.REPAIR,
    )


func apply_restore() -> void:
    var zone_factor: float = RESTORE_ZONE_FACTORS[1.0]
    if condition < 0.75:
        zone_factor = RESTORE_ZONE_FACTORS[0.75]
    var rarity_factor: float = RESTORE_RARITY_FACTOR[item_data.rarity]
    var restoration_skill: SkillData = KnowledgeManager.get_skill_by_id("restoration")
    var restoration_level: int = 0
    if restoration_skill != null:
        restoration_level = KnowledgeManager.get_level(restoration_skill)
    var restore_skill_mult: float = 1.0 + restoration_level * RESTORE_SKILL_COEFF
    var cat_skill: SkillData = item_data.category_data.super_category.restore_skill
    var cat_skill_mult: float = 1.0
    if cat_skill != null:
        cat_skill_mult = 1.0 + KnowledgeManager.get_level(cat_skill) * RESTORE_CAT_SKILL_COEFF
    var delta: float = RESTORE_BASE * zone_factor * rarity_factor * restore_skill_mult * cat_skill_mult
    condition = minf(condition + delta, 1.0)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.RESTORE,
    )


func advance_layer() -> void:
    _reveal_layer_clues(_safe_layer_index())
    layer_index += 1
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.REVEAL,
    )


# Advances this entry directly to its final perceived identity layer.
# Used by Hub final-layer resolution (Phase 5) and apply_storage_migration().
func advance_to_final_layer() -> void:
    if item_data == null or item_data.identity_layers.is_empty():
        return
    layer_index = item_data.identity_layers.size() - 1
    inspected = true
    for layer: IdentityLayer in item_data.identity_layers:
        for clue: ClueData in layer.clues:
            if not revealed_clue_ids.has(clue.clue_id):
                revealed_clue_ids.append(clue.clue_id)


# Called after item reveal in the Inspection scene.
# Reveals clues for the current layer whose prerequisites are already met.
func reveal_passive_clues() -> void:
    if item_data == null:
        return
    var layer := active_layer()
    if layer == null:
        return
    for clue: ClueData in layer.clues:
        if revealed_clue_ids.has(clue.clue_id):
            continue
        if _clue_prerequisites_met(clue):
            revealed_clue_ids.append(clue.clue_id)


# Idempotent migration applied to every ItemEntry when it enters or is loaded
# from Storage. Ensures the entry is always at its final perceived layer.
# Add future per-entry migration steps here so SaveManager stays free of
# entry-level logic.
func apply_storage_migration() -> void:
    advance_to_final_layer()


func is_repair_complete() -> bool:
    return condition >= 0.5


func is_restore_complete() -> bool:
    return condition >= 1.0


var price_convergence_ratio: float:
    get:
        return inspection_level


func is_price_converged() -> bool:
    return price_convergence_ratio >= 1.0


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
        if verified:
            return item_data.base_price
        var layer := active_layer()
        if layer == null:
            return 0
        var spread: float = 0.5 * (1.0 - inspection_level)
        var offset: float = center_offset * (1.0 - inspection_level)
        var mult: float = 1.0 - spread + offset
        return maxi(1, int(layer.base_value * mult))

var estimated_value_max: int:
    get:
        if is_veiled():
            return 0
        if verified:
            return item_data.base_price
        var layer := active_layer()
        if layer == null:
            return 0
        var spread: float = 0.0
        var offset: float = center_offset * (1.0 - inspection_level)
        var base_value: int = layer.base_value
        if not is_at_final_layer() and item_data != null:
            var next_layer: IdentityLayer = item_data.identity_layers[_safe_layer_index() + 1]
            base_value = next_layer.base_value
            spread = 0.5 * (1.0 - inspection_level)
        else:
            spread = 0.3 * (1.0 - inspection_level)
        var mult: float = 1.0 + spread + offset
        return maxi(1, int(base_value * mult))


func estimated_value_text() -> String:
    if is_veiled():
        return UNKNOWN_TEXT
    if verified:
        return "$%d" % item_data.base_price

    var text: String
    var lo: int = estimated_value_min
    var hi: int = estimated_value_max
    if hi <= lo:
        text = "$%d" % lo
    else:
        text = "$%d - $%d" % [lo, hi]

    if not is_at_final_layer():
        text += "+"

    return text


# Unified pricing pipeline. Reads the active layer's base value, then
# conditionally folds in condition, knowledge, and market factors based on the
# supplied PriceConfig, and finally scales by config.multiplier.
func compute_price(config: PriceConfig) -> int:
    var value: float = float(item_data.base_price if verified else active_layer().base_value)

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
            item_data.category_data,
        )

    value *= config.multiplier
    return int(value)


var market_price: int:
    get:
        return compute_price(ItemRegistry.price_config_with_market)

var market_factor_delta: float:
    get:
        return MarketManager.get_category_factor(
            item_data.category_data,
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


# Stage-aware price text. ItemCard / ItemRow / ItemRowTooltip / inspection_scene
# dispatch through this so a single Stage enum drives the visible value.
func price_text_for(ctx: ItemViewContext) -> String:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO, \
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return estimated_value_text()
        ItemViewContext.Stage.MERCHANT_SHOP:
            return merchant_offer_text(ctx.merchant)
        ItemViewContext.Stage.FULFILLMENT_PANEL:
            return special_order_text(ctx.order)
        _:
            push_warning("Unknown Stage for price: %d" % ctx.stage)
            return estimated_value_text()


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
    if verified:
        return item_data.base_price
    return estimated_value_min


func base_value_sort_value() -> int:
    if is_veiled():
        return 0
    if verified:
        return item_data.base_price
    return active_layer().base_value


func merchant_offer_value(merchant: MerchantData) -> int:
    return merchant.offer_for(self) if merchant else market_price


func special_order_value(order: SpecialOrder) -> int:
    return order.compute_item_price(self) if order else 0


func condition_text() -> String:
    if is_veiled():
        return UNKNOWN_TEXT
    match get_condition_bucket():
        0:
            return UNKNOWN_TEXT
        1:
            return "Poor" if condition < 0.5 else "Good"
        2:
            if condition < 0.25:
                return "Poor"
            elif condition < 0.5:
                return "Fair"
            elif condition < 0.75:
                return "Good"
            else:
                return "Excellent"
        _:
            push_warning("Unknown condition bucket: %d" % get_condition_bucket())
            return UNKNOWN_TEXT


func condition_label() -> Label:
    var label := Label.new()
    label.text = condition_text()
    label.modulate = condition_display_color()
    return label


func condition_secondary_text() -> String:
    if condition_text() == UNKNOWN_TEXT:
        return ""
    match get_condition_bucket():
        1:
            return "~×%.2f" % get_known_condition_multiplier()
        2:
            return "×%.2f" % get_condition_multiplier()
        _:
            push_warning("condition bucket out of range: %d" % get_condition_bucket())
            return "×?"


func condition_detail_text() -> String:
    var text := condition_text()
    if text == UNKNOWN_TEXT:
        return ""
    return "Condition:  %s (%s)" % [text, condition_secondary_text()]


func condition_mult_label() -> Label:
    var label := Label.new()
    label.text = condition_secondary_text()
    return label


func base_value_text() -> String:
    if is_veiled():
        return UNKNOWN_TEXT
    if verified:
        return "$%d" % item_data.base_price
    return "$%d" % active_layer().base_value


func merchant_offer_text(merchant: MerchantData) -> String:
    return "$%d" % merchant_offer_value(merchant)


func special_order_text(order: SpecialOrder) -> String:
    return "$%d" % special_order_value(order)

# ── Label factories ──────────────────────────────────────────────────────────
# One factory per colour/state-bearing field. Centralising the colour decision
# here so all three scenes (inspection / merchant_shop / storage) share it.


func display_name_label() -> Label:
    var label := Label.new()
    label.text = display_name
    label.add_theme_color_override(&"font_color", display_name_color())
    return label


func estimated_value_label() -> Label:
    var label := Label.new()
    label.text = estimated_value_text()
    label.add_theme_color_override(&"font_color", price_display_color())
    return label


func base_value_label() -> Label:
    var label := Label.new()
    label.text = base_value_text()
    label.add_theme_color_override(&"font_color", price_display_color())
    return label


func merchant_offer_label(merchant: MerchantData) -> Label:
    var label := Label.new()
    label.text = merchant_offer_text(merchant)
    label.add_theme_color_override(&"font_color", price_display_color())
    return label


func special_order_label(order: SpecialOrder) -> Label:
    var label := Label.new()
    label.text = special_order_text(order)
    label.add_theme_color_override(&"font_color", price_display_color())
    return label


func price_label_for(ctx: ItemViewContext) -> Label:
    var label := Label.new()
    label.text = price_text_for(ctx)
    label.add_theme_color_override(&"font_color", price_display_color())
    return label


func rarity_text() -> String:
    if is_veiled() or item_data == null:
        return ItemEntry.UNKNOWN_TEXT
    return _true_rarity_name() if verified else ItemEntry.UNKNOWN_TEXT


func weight_text() -> String:
    var category := category_data()
    if is_veiled() or category == null:
        return ItemEntry.UNKNOWN_TEXT
    return "%.1f kg" % category.weight


func grid_text() -> String:
    var category := category_data()
    if is_veiled() or category == null:
        return ItemEntry.UNKNOWN_TEXT
    return "%d  %s" % [category.get_cells().size(), category.shape_id]


func market_factor_text() -> String:
    return ItemEntry.UNKNOWN_TEXT if is_veiled() else "%+d%%" % int(round(market_factor_delta * 100))


func research_status_text() -> String:
    if id == -1:
        return ""
    for d: Dictionary in SaveManager.research_slots:
        var slot_item_id: int = int(d.get("item_id", -1))
        if slot_item_id == -1 or slot_item_id != id:
            continue
        if bool(d.get("completed", false)):
            return "✓"
        var action_string: String = String(d.get("action", ""))
        match action_string:
            "repair":
                return "R"
            "unlock":
                return "U"
            "authenticate":
                return "A"
            _:
                return "?"
    return ""


func inspection_text() -> String:
    return ItemEntry.UNKNOWN_TEXT if is_veiled() else "%d%%" % int(price_convergence_ratio * 100)


func price_display_color() -> Color:
    return price_color


func condition_display_color() -> Color:
    return condition_color


func display_name_color() -> Color:
    if is_veiled() or not verified or item_data == null:
        return Color.WHITE
    match item_data.rarity:
        ItemData.Rarity.UNCOMMON:
            return Color(0.4, 0.8, 0.4)
        ItemData.Rarity.RARE:
            return Color(0.3, 0.6, 1.0)
        ItemData.Rarity.EPIC:
            return Color(0.7, 0.4, 1.0)
        ItemData.Rarity.LEGENDARY:
            return Color(1.0, 0.75, 0.2)
        _:
            return Color(0.85, 0.85, 0.85)


func category_data() -> CategoryData:
    return item_data.category_data if item_data != null else null


func super_category_text() -> String:
    var category := category_data()
    if category == null or category.super_category == null:
        return ""
    return category.super_category.display_name


func category_text() -> String:
    var category := category_data()
    return category.display_name if category != null else ""


func can_inspect() -> bool:
    return is_veiled()


func can_advance() -> bool:
    return not is_veiled() and not is_at_final_layer()


func perform_inspect() -> StringName:
    if is_veiled():
        unveil()
        KnowledgeManager.add_category_points(
            item_data.category_data,
            item_data.rarity,
            KnowledgeManager.KnowledgeAction.REVEAL,
        )
        return &"unveil"
    return &"condition"


func sort_value(column: int, ctx: ItemViewContext) -> Variant:
    match column:
        ItemEntry.COLUMN_NAME:
            return display_name
        ItemEntry.COLUMN_CONDITION:
            if is_veiled() or get_condition_bucket() == 0:
                return 0.0
            return get_known_condition_multiplier()
        ItemEntry.COLUMN_ESTIMATED_VALUE:
            return estimated_value_sort_value()
        ItemEntry.COLUMN_BASE_VALUE:
            return base_value_sort_value()
        ItemEntry.COLUMN_MERCHANT_OFFER:
            return merchant_offer_value(ctx.merchant)
        ItemEntry.COLUMN_SPECIAL_ORDER:
            return special_order_value(ctx.order)
        ItemEntry.COLUMN_RARITY:
            return float(item_data.rarity) if verified and item_data != null else -1.0
        ItemEntry.COLUMN_WEIGHT:
            var weight_category := category_data()
            return weight_category.weight if weight_category != null else 0.0
        ItemEntry.COLUMN_GRID:
            var grid_category := category_data()
            return grid_category.get_cells().size() if grid_category != null else 0
        ItemEntry.COLUMN_MARKET_FACTOR:
            return market_factor_delta
        ItemEntry.COLUMN_RESEARCH_STATUS:
            for d: Dictionary in SaveManager.research_slots:
                if int(d.get("item_id", -1)) == id:
                    if bool(d.get("completed", false)):
                        return 2
                    return 1
            return 0
        ItemEntry.COLUMN_INSPECTION:
            return price_convergence_ratio
        _:
            push_warning("Unknown Column: %d" % column)
            return 0


# Returns the layer currently visible to the player.
func active_layer() -> IdentityLayer:
    if item_data == null or item_data.identity_layers.is_empty():
        return null
    return item_data.identity_layers[_safe_layer_index()]


# Returns the unlock_action for advancing beyond the current layer.
# Null if already at the final layer.
func current_unlock_action() -> LayerUnlockAction:
    if item_data == null or item_data.identity_layers.is_empty():
        return null
    return item_data.identity_layers[_safe_layer_index()].unlock_action


# True if the item has not been inspected yet. Kept as the compatibility API
# for existing display and auction/list-review logic.
func is_veiled() -> bool:
    return not inspected


# True if no further layers exist.
func is_at_final_layer() -> bool:
    if item_data == null or item_data.identity_layers.is_empty():
        return true
    return _safe_layer_index() == item_data.identity_layers.size() - 1


# Marks an uninspected item as inspected. Shared by the reveal scene and the
# inspection action. Runtime entries already start at layer 1.
func unveil() -> void:
    if not is_veiled():
        return
    inspected = true

# ── Private helpers ──────────────────────────────────────────────────────────


func _reveal_layer_clues(layer_idx: int) -> void:
    if item_data == null or layer_idx < 0 or layer_idx >= item_data.identity_layers.size():
        return
    for clue: ClueData in item_data.identity_layers[layer_idx].clues:
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


func _clue_prerequisites_met(clue: ClueData) -> bool:
    if clue.required_skill != null:
        if KnowledgeManager.get_level(clue.required_skill) < clue.required_level:
            return false
    if clue.required_category_rank > 0:
        if KnowledgeManager.get_category_rank(item_data.category_data) < clue.required_category_rank:
            return false
    if clue.required_perk != null:
        if not KnowledgeManager.has_perk(clue.required_perk):
            return false
    return true


func _safe_layer_index() -> int:
    if item_data == null:
        return 0
    var n: int = item_data.identity_layers.size()
    if n == 0:
        return 0
    # Single-layer items pin to 0; multi-layer items clamp to [1, n-1] so the
    # runtime never reads the legacy layer-0 veil row.
    var lo: int = 0 if n == 1 else 1
    var hi: int = n - 1
    return clampi(layer_index, lo, hi)

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()
    entry.center_offset = randf_range(-0.5, 0.5)

    entry.layer_index = 1
    entry.inspected = false

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "layer_index": layer_index,
        "inspected": inspected,
        "condition": condition,
        "center_offset": center_offset,
        "verified": verified,
        "revealed_clue_ids": revealed_clue_ids.duplicate(),
    }


static func from_dict(d: Dictionary) -> ItemEntry:
    var data: ItemData = ItemRegistry.get_item_by_id(d["item_id"])
    if data == null:
        push_error("ItemEntry: item not found for id '%s'" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = data
    var saved_layer_index := int(d.get("layer_index", 1))
    entry.inspected = bool(d.get("inspected", false))
    entry.layer_index = saved_layer_index
    entry.condition = float(d["condition"])
    if d.has("center_offset"):
        entry.center_offset = float(d["center_offset"])

    if d.has("id"):
        entry.id = int(d["id"])
    if d.has("verified"):
        entry.verified = bool(d["verified"])
    if d.has("revealed_clue_ids"):
        var raw: Array = d["revealed_clue_ids"]
        for clue_id_value in raw:
            entry.revealed_clue_ids.append(String(clue_id_value))
    return entry
