# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── Inspection constants ─────────────────────────────────────────────────────

# Condition display thresholds against inspection_level (0–1).
const CONDITION_THRESHOLDS: Array[float] = [0.0, 0.33, 0.66]

# Display names indexed by ItemData.Rarity enum value.
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# Uniform maximum range spread, in multiplier units around 1.0.
const PRICE_MAX_SPREAD: float = 1.0

# ── Scrutiny tuning knobs ────────────────────────────────────────────────────

const SCRUTINY_BASE_DELTA: float = 0.1
const MAX_SCRUTINY: float = 0.6
const SCRUTINY_SKILL_COEFF: float = 0.35

# ── Computed-base weights ────────────────────────────────────────────────────

const COMPUTED_BASE_CAT_WEIGHT: float = 0.15
const COMPUTED_BASE_SC_WEIGHT: float = 0.03
const COMPUTED_BASE_SKILL_WEIGHT: float = 0.05

# ── Rarity divisors keyed by ItemData.Rarity enum ────────────────────────────

const RARITY_DIVISORS: Dictionary = {
    ItemData.Rarity.COMMON: 1,
    ItemData.Rarity.UNCOMMON: 2,
    ItemData.Rarity.RARE: 3,
    ItemData.Rarity.EPIC: 4,
    ItemData.Rarity.LEGENDARY: 5,
}

const INTUITION_INSPECTION_BONUS: float = 0.1

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

const UNLOCK_BASE_EFFORT: float = 1.0

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# How far the player has advanced the identity chain this run.
# 0 = base layer (always visible); max = identity_layers.size() - 1.
var layer_index: int = 0

var condition: float = 1.0

# Per-item inspection effort, advanced by Inspect and Study actions.
var scrutiny: float = 0.0

var intuition_level: int = 0

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

# Lazy-cached appraisal skill reference.
var _appraisal_skill: SkillData = null

# ══ Computed properties ═══════════════════════════════════════════════════════

# inspection_level is now fully computed, not stored.
var inspection_level: float:
    get:
        var category_rank: int = KnowledgeManager.get_category_rank(item_data.category_data)
        var sc: SuperCategoryData = item_data.category_data.super_category
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc)
        var cat_count: int = SuperCategoryRegistry.get_categories_for_super(sc).size()
        var sc_average: float = float(sc_rank) / maxf(cat_count, 1.0)
        var appraisal_level: int = _get_appraisal_level()
        var computed_base: float = (
            category_rank * COMPUTED_BASE_CAT_WEIGHT
            + sc_average * COMPUTED_BASE_SC_WEIGHT
            + appraisal_level * COMPUTED_BASE_SKILL_WEIGHT
        )
        var rarity_divisor: float = float(RARITY_DIVISORS.get(item_data.rarity, 1))
        var intuition_bonus: float = INTUITION_INSPECTION_BONUS if intuition_level >= 1 else 0.0
        return clampf(computed_base / rarity_divisor + scrutiny + intuition_bonus, 0.0, 1.0)

var max_intuition_level: int:
    get:
        return item_data.identity_layers.size() - 1 - layer_index

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
                if condition < 0.5:
                    return "Poor"
                else:
                    return "Good"
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


func is_condition_inspectable() -> bool:
    return scrutiny < MAX_SCRUTINY


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
            return 0.0

# Rarity label the player can see, driven by layer depth (+ intuition_level).
var perceived_rarity_label: String:
    get:
        var effective_layer: int = layer_index + intuition_level
        var rarity_value: int = item_data.rarity

        # effective_layer 0 (veiled): no rarity shown.
        if effective_layer <= 0:
            return "Veiled"

        # Layer-based rarity reveal table
        match effective_layer:
            1:
                if rarity_value == ItemData.Rarity.COMMON:
                    return "Common"
                else:
                    return "Uncommon+"
            2:
                if rarity_value <= ItemData.Rarity.UNCOMMON:
                    return _true_rarity_name()
                else:
                    return "Rare+"
            3:
                if rarity_value <= ItemData.Rarity.RARE:
                    return _true_rarity_name()
                else:
                    return "Epic+"
            _:
                # 4+ → all show true name
                return _true_rarity_name()

# Sort-safe rarity value based on what the player can actually see.
# Confirmed rarity → enum int (0–4). Unconfirmed floor ("X+") → enum + 0.5.
# Veiled → -1.
var perceived_rarity: float:
    get:
        if is_veiled():
            return -1.0
        var effective_layer: int = layer_index + intuition_level
        var rarity_value: int = item_data.rarity

        if effective_layer <= 0:
            return -1.0

        match effective_layer:
            1:
                if rarity_value == ItemData.Rarity.COMMON:
                    return float(ItemData.Rarity.COMMON)
                else:
                    return float(ItemData.Rarity.UNCOMMON) + 0.5
            2:
                if rarity_value <= ItemData.Rarity.UNCOMMON:
                    return float(rarity_value)
                else:
                    return float(ItemData.Rarity.RARE) + 0.5
            3:
                if rarity_value <= ItemData.Rarity.RARE:
                    return float(rarity_value)
                else:
                    return float(ItemData.Rarity.EPIC) + 0.5
            _:
                return float(rarity_value)

# ── Bucket helpers ────────────────────────────────────────────────────────────


func get_condition_bucket() -> int:
    return _bucket_index(inspection_level, CONDITION_THRESHOLDS)


func is_fully_inspected() -> bool:
    return inspection_level >= 1.0


func is_study_complete() -> bool:
    return scrutiny >= MAX_SCRUTINY


func advance_scrutiny() -> void:
    var appraisal_level: int = _get_appraisal_level()
    var skill_multiplier: float = 1.0 + appraisal_level * SCRUTINY_SKILL_COEFF
    var delta: float = SCRUTINY_BASE_DELTA * skill_multiplier
    scrutiny = minf(scrutiny + delta, MAX_SCRUTINY)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.APPRAISE,
    )


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
        KnowledgeManager.KnowledgeAction.REPAIR,
    )


func add_unlock_effort() -> void:
    var action: LayerUnlockAction = current_unlock_action()
    if action:
        unlock_progress = minf(action.difficulty, unlock_progress + UNLOCK_BASE_EFFORT)
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
    return condition >= 0.5


func is_restore_complete() -> bool:
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
        return inspection_level


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
            item_data.category_data,
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
    var spread: float = _max_spread() * (1.0 - inspection_level)
    var offset: float = center_offset * (1.0 - inspection_level)
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
    advance_scrutiny()

# ── Private helpers ──────────────────────────────────────────────────────────


func _get_appraisal_level() -> int:
    if _appraisal_skill == null:
        _appraisal_skill = KnowledgeManager.get_skill_by_id("appraisal")
    if _appraisal_skill == null:
        return 0
    return KnowledgeManager.get_level(_appraisal_skill)

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData, veil_chance: float = 0.0) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()
    entry.center_offset = randf_range(-0.5, 0.5)

    # Layer 0 = veiled. If veil does not apply, auto-advance to layer 1.
    var start_veiled := randf() < veil_chance
    entry.layer_index = 0 if start_veiled else 1

    # scrutiny starts at 0; inspection_level is computed from knowledge + scrutiny.
    entry.scrutiny = 0.0
    entry.intuition_level = 0

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "layer_index": layer_index,
        "condition": condition,
        "scrutiny": scrutiny,
        "intuition_level": intuition_level,
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
    # New fields — default gracefully if missing (migration-safe).
    entry.scrutiny = float(d.get("scrutiny", 0.0))
    if d.has("intuition_level"):
        entry.intuition_level = int(d["intuition_level"])
    elif bool(d.get("intuition_flag", false)):
        entry.intuition_level = 1
    if d.has("center_offset"):
        entry.center_offset = float(d["center_offset"])
    else:
        entry.center_offset = randf_range(-0.5, 0.5)
    if d.has("unlock_progress"):
        entry.unlock_progress = float(d["unlock_progress"])
    if d.has("id"):
        entry.id = int(d["id"])
    # Legacy inspection_level key is intentionally ignored — clean break.
    return entry
