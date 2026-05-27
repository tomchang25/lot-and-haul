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
const RESTORE_ATTR_COEFF: float = 0.4

# ── Pricing ──────────────────────────────────────────────────────────────────

const MAX_SPREAD: float = 0.5

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# False until the player has inspected/revealed this entry.
var inspected: bool = false

# True after the anchor clue has been revealed (auto-revealed on first inspect).
var anchor_revealed: bool = false

var condition: float = 1.0

# Unique persistent ID assigned when this entry enters storage.
# -1 = not yet in storage. Assigned by SaveManager
var id: int = -1

# Rolled once at creation in [-0.5, 0.5]. Biases the estimated range away from
# the true price at low inspection; its contribution scales to zero at max
# inspection so the range always converges on the true value.
var center_offset: float = 0.0

# True after Storage Authenticate completes. Reveals hidden clues.
var verified: bool = false

var revealed_clue_ids: Array[String] = []

# ══ Clue helpers ══════════════════════════════════════════════════════════════


func _anchor_clue() -> ClueData:
    if item_data == null:
        return null
    for clue: ClueData in item_data.clues:
        if clue.type == "anchor":
            return clue
    return null


func _surface_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.type == "surface":
            result.append(clue)
    return result


func _hidden_clues() -> Array[ClueData]:
    if item_data == null:
        return []
    var result: Array[ClueData] = []
    for clue: ClueData in item_data.clues:
        if clue.type == "hidden":
            result.append(clue)
    return result


func _revealed_surface_count() -> int:
    var count := 0
    for clue: ClueData in _surface_clues():
        if revealed_clue_ids.has(clue.clue_id):
            count += 1
    return count


func _total_surface_count() -> int:
    return _surface_clues().size()


func all_surface_revealed() -> bool:
    return _revealed_surface_count() >= _total_surface_count()


## Applies a single clue's price effect to [param base] and returns the result.
## Dispatches on [member ClueData.effect_op]:
##   "flat" — sets the baseline price (anchor-only; currently same as "add"),
##   "add"  — adds [member ClueData.effect_amount] to [param base],
##   "mul"  — multiplies [param base] by [member ClueData.effect_amount].
## Unknown ops leave [param base] unchanged.
func _apply_price_effect(base: float, clue: ClueData) -> float:
    match clue.effect_op:
        "flat":
            return clue.effect_amount
        "add":
            return base + clue.effect_amount
        "mul":
            return base * clue.effect_amount
    return base


# Computes the total modifier multiplier from all hidden clues.
func _hidden_multiplier() -> float:
    var mult := 1.0
    for clue: ClueData in _hidden_clues():
        if revealed_clue_ids.has(clue.clue_id):
            if clue.effect_op == "mul":
                mult *= clue.effect_amount
    return mult

# ══ Computed properties ═══════════════════════════════════════════════════════

# inspection_level based on surface clue reveal ratio.
var inspection_level: float:
    get:
        if not inspected or not anchor_revealed:
            return 0.0
        var total := _total_surface_count()
        if total == 0:
            return 1.0
        return float(_revealed_surface_count()) / float(total)

var display_name: String:
    get:
        if is_veiled():
            return "Unknown Item"
        if verified:
            if item_data.item_name.is_empty():
                push_warning("ItemEntry %d: verified but item_name is empty" % id)
                return "Unknown E2 9C 93"
            return "%s E2 9C 93" % item_data.item_name
        var anchor := _anchor_clue()
        if anchor != null:
            var name: String = anchor.known_text
            if id >= 0 and ResearchSlot.action_for_item(SaveManager.research_slots, id) != "":
                name += " E2 9A 99"
            return name
        return "Unknown Item"


func get_condition_multiplier() -> float:
    if condition <= 0.25:
        return remap(condition, 0.0, 0.25, 0.25, 0.5)
    elif condition <= 0.5:
        return remap(condition, 0.25, 0.5, 0.5, 1.0)
    elif condition <= 0.75:
        return remap(condition, 0.5, 0.75, 1.0, 2.0)
    else:
        return remap(condition, 0.75, 1.0, 2.0, 4.0)


func get_known_condition_multiplier() -> float:
    if is_veiled():
        return 1.0
    return get_condition_multiplier()

# ── Bucket helpers ────────────────────────────────────────────────────────────


func is_fully_inspected() -> bool:
    return inspection_level >= 1.0


func is_price_converged() -> bool:
    return price_convergence_ratio >= 1.0


var price_convergence_ratio: float:
    get:
        return inspection_level


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
    var restoration_attr := KnowledgeManager.get_attribute_value("restoration")
    var attr_mult: float = 1.0 + restoration_attr * RESTORE_ATTR_COEFF
    var delta: float = RESTORE_BASE * zone_factor * rarity_factor * attr_mult
    condition = minf(condition + delta, 1.0)
    KnowledgeManager.add_category_points(
        item_data.category_data,
        item_data.rarity,
        KnowledgeManager.KnowledgeAction.RESTORE,
    )

# ── Clue reveal mechanics ─────────────────────────────────────────────────────


func reveal_anchor() -> void:
    var anchor := _anchor_clue()
    if anchor == null:
        return
    if not revealed_clue_ids.has(anchor.clue_id):
        revealed_clue_ids.append(anchor.clue_id)
    anchor_revealed = true


func attempt_surface_clue(clue: ClueData, attribute_bonus: int) -> bool:
    if clue == null or clue.type != "surface":
        return false
    var success_chance := clampi((21 + attribute_bonus - clue.dc) * 5, 5, 95)
    var roll := randi() % 100 + 1 # 1–100 percentile roll
    var succeeded := roll <= success_chance
    if succeeded and not revealed_clue_ids.has(clue.clue_id):
        revealed_clue_ids.append(clue.clue_id)
    return succeeded


func auto_reveal_all_surface() -> void:
    for clue: ClueData in _surface_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


func reveal_all_hidden() -> void:
    for clue: ClueData in _hidden_clues():
        if not revealed_clue_ids.has(clue.clue_id):
            revealed_clue_ids.append(clue.clue_id)


# Idempotent migration applied to every ItemEntry when it enters or is loaded
# from Storage. Replaced old advance_to_final_layer with auto-reveal surfaces.
func apply_storage_migration() -> void:
    auto_reveal_all_surface()


func is_repair_complete() -> bool:
    return condition >= 0.5


func is_restore_complete() -> bool:
    return condition >= 1.0

# ── Anchor value (int) ────────────────────────────────────────────────────────


func _anchor_flat_value() -> int:
    var anchor := _anchor_clue()
    if anchor == null:
        return 0
    return int(anchor.effect_amount)

# ── Appraised value ────────────────────────────────────────────────────────────


# appraised_value = anchor flat value + sum of revealed surface flat modifiers
func _raw_appraised_value() -> float:
    var value := float(_anchor_flat_value())
    for clue: ClueData in _surface_clues():
        if revealed_clue_ids.has(clue.clue_id):
            value = _apply_price_effect(value, clue)
    return value


## Returns a simulated NPC price estimate for this item based on a random subset
## of surface clues the NPC happens to notice. Starts from the anchor flat value
## (not zero) so multiplicative surface effects apply correctly.
## sight_chance: per-clue probability the NPC notices each surface clue.
func roll_npc_estimate(sight_chance: float) -> int:
    var anchor := _anchor_clue()
    if anchor == null:
        return 0
    var value := float(_anchor_flat_value())
    for clue: ClueData in _surface_clues():
        if randf() < sight_chance:
            value = _apply_price_effect(value, clue)
    return int(value)

# ── Estimated value (range) ────────────────────────────────────────────────────

var estimated_value_min: int:
    get:
        if is_veiled() or not anchor_revealed:
            return 0
        if verified:
            return maxi(1, int(_raw_appraised_value() * _hidden_multiplier() * get_condition_multiplier()))
        var base := _raw_appraised_value()
        var spread: float = MAX_SPREAD * (1.0 - self.inspection_level)
        var offset: float = center_offset * (1.0 - self.inspection_level)
        var mult: float = 1.0 - spread + offset
        return maxi(1, int(base * mult * get_condition_multiplier()))

var estimated_value_max: int:
    get:
        if is_veiled() or not anchor_revealed:
            return 0
        if verified:
            return maxi(1, int(_raw_appraised_value() * _hidden_multiplier() * get_condition_multiplier()))
        var base := _raw_appraised_value()
        var spread: float = MAX_SPREAD * (1.0 - self.inspection_level)
        var offset: float = center_offset * (1.0 - self.inspection_level)
        var mult: float = 1.0 + spread + offset
        return maxi(1, int(base * mult * get_condition_multiplier()))

# ── Display text helpers ──────────────────────────────────────────────────────


func estimated_value_text() -> String:
    if is_veiled() or not anchor_revealed:
        return UNKNOWN_TEXT
    if verified:
        return "$%d" % int(_raw_appraised_value() * _hidden_multiplier())

    var lo: int = estimated_value_min
    var hi: int = estimated_value_max
    if hi <= lo:
        return "$%d" % lo
    return "$%d - $%d" % [lo, hi]


# Unified pricing pipeline. Uses anchor + surface modifiers (non-verified)
# or anchor + surface + hidden (verified), then folds in condition and market.
func compute_price(config: PriceConfig) -> int:
    var value: float
    if verified:
        value = _raw_appraised_value() * _hidden_multiplier()
    else:
        value = _raw_appraised_value()

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

var condition_color: Color:
    get:
        if is_veiled():
            return Color(0.5, 0.5, 0.5)
        if condition >= 0.8:
            return Color.GOLD
        elif condition >= 0.6:
            return Color.GREEN_YELLOW
        elif condition >= 0.3:
            return Color.WHITE
        else:
            return Color.LIGHT_CORAL

const PRICE_COLOR := Color(0.4, 1.0, 0.5)
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

var price_color: Color:
    get:
        return PRICE_UNKNOWN_COLOR if is_veiled() or not anchor_revealed else PRICE_COLOR

# ── Context-aware helpers ─────────────────────────────────────────────────────


func price_text_for(ctx: ItemViewContext) -> String:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO, \
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return estimated_value_text()
        ItemViewContext.Stage.MERCHANT_SHOP: # DEPRECATED: Phase 9
            return merchant_offer_text(ctx.merchant)
        ItemViewContext.Stage.FULFILLMENT_PANEL: # DEPRECATED: Phase 9
            return special_order_text(ctx.order)
        _:
            push_warning("Unknown Stage for price: %d" % ctx.stage)
            return estimated_value_text()


func price_value_for(ctx: ItemViewContext) -> int:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO, \
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return estimated_value_sort_value()
        ItemViewContext.Stage.MERCHANT_SHOP: # DEPRECATED: Phase 9
            return merchant_offer_value(ctx.merchant)
        ItemViewContext.Stage.FULFILLMENT_PANEL: # DEPRECATED: Phase 9
            return special_order_value(ctx.order)
        _:
            push_warning("Unknown Stage for price: %d" % ctx.stage)
            return 0

# ── Per-column price getters ─────────────────────────────────────────────────


func estimated_value_sort_value() -> int:
    return estimated_value_min


func base_value_sort_value() -> int:
    if is_veiled() or not anchor_revealed:
        return 0
    if verified:
        return int(_raw_appraised_value() * _hidden_multiplier())
    return _anchor_flat_value()


## DEPRECATED: Removed in Phase 9 (merchant system redesign → unified customer selling).
func merchant_offer_value(merchant: MerchantData) -> int:
    return merchant.offer_for(self) if merchant else market_price


## DEPRECATED: Removed in Phase 9 (merchant system redesign → unified customer selling).
func special_order_value(order: SpecialOrder) -> int:
    return order.compute_item_price(self) if order else 0


func condition_text() -> String:
    if is_veiled():
        return UNKNOWN_TEXT
    return "%d%%" % int(condition * 100)


func condition_secondary_text() -> String:
    if is_veiled():
        return ""
    return "x%.2f" % get_condition_multiplier()


func condition_detail_text() -> String:
    var text := condition_text()
    if text == UNKNOWN_TEXT:
        return ""
    return "Condition:  %s (%s)" % [text, condition_secondary_text()]


func base_value_text() -> String:
    if is_veiled() or not anchor_revealed:
        return UNKNOWN_TEXT
    if verified:
        return "$%d" % int(_raw_appraised_value() * _hidden_multiplier())
    return "$%d" % _anchor_flat_value()


## DEPRECATED: Removed in Phase 9 (merchant system redesign → unified customer selling).
func merchant_offer_text(merchant: MerchantData) -> String:
    return "$%d" % merchant_offer_value(merchant)


## DEPRECATED: Removed in Phase 9 (merchant system redesign → unified customer selling).
func special_order_text(order: SpecialOrder) -> String:
    return "$%d" % special_order_value(order)


func rarity_text() -> String:
    if is_veiled() or item_data == null:
        return ItemEntry.UNKNOWN_TEXT

    var r: int = item_data.rarity
    if r >= 0 and r < RARITY_NAMES.size():
        return RARITY_NAMES[r]

    return ItemEntry.UNKNOWN_TEXT


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
            return "E2 9C 93"
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
    return ItemEntry.UNKNOWN_TEXT if is_veiled() or not anchor_revealed else "%d%%" % int(price_convergence_ratio * 100)


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
    return anchor_revealed and not all_surface_revealed()


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
            if is_veiled():
                return 0.0
            return get_condition_multiplier()
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


func is_veiled() -> bool:
    return not inspected


# Marks an uninspected item as inspected.
func unveil() -> void:
    if not is_veiled():
        return
    inspected = true

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()
    entry.center_offset = randf_range(-0.5, 0.5)

    entry.inspected = false
    entry.anchor_revealed = false

    return entry

# ══ Serialization ═════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "item_id": item_data.item_id,
        "id": id,
        "anchor_revealed": anchor_revealed,
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
    entry.inspected = bool(d.get("inspected", false))

    entry.anchor_revealed = bool(d.get("anchor_revealed", false))

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
