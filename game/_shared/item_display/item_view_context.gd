# item_view_context.gd
# Describes the display rules for a given stage.
# Pass one instance to ItemRow, ItemCard, and ItemRowTooltip.
# UI components never branch on stage directly — they read the mode fields only.
class_name ItemViewContext
extends RefCounted

enum Stage {
    INSPECTION,
    LIST_REVIEW,
    REVEAL,
    CARGO,
    RUN_REVIEW,
    STORAGE,
}

enum ConditionMode {
    RESPECT_INSPECT_LEVEL,
    FORCE_INSPECT_MAX,
    FORCE_TRUE_VALUE,
}

enum PotentialMode {
    RESPECT_INSPECT_LEVEL,
    FORCE_FULL,
}

enum PriceMode {
    CURRENT_ESTIMATE,
    SELL_PRICE,
    BASE_VALUE,
}

var stage: Stage
var condition_mode: ConditionMode = ConditionMode.RESPECT_INSPECT_LEVEL
var potential_mode: PotentialMode = PotentialMode.RESPECT_INSPECT_LEVEL
var price_mode: PriceMode = PriceMode.CURRENT_ESTIMATE

# ── Factories ─────────────────────────────────────────────────────────────────


static func for_inspection() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.INSPECTION
    return ctx


static func for_list_review() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.LIST_REVIEW
    ctx.condition_mode = ConditionMode.RESPECT_INSPECT_LEVEL
    ctx.potential_mode = PotentialMode.RESPECT_INSPECT_LEVEL
    ctx.price_mode = PriceMode.CURRENT_ESTIMATE

    return ctx


static func for_reveal() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.REVEAL
    ctx.condition_mode = ConditionMode.RESPECT_INSPECT_LEVEL
    ctx.potential_mode = PotentialMode.RESPECT_INSPECT_LEVEL
    ctx.price_mode = PriceMode.CURRENT_ESTIMATE

    return ctx


static func for_cargo() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.CARGO
    ctx.condition_mode = ConditionMode.FORCE_INSPECT_MAX
    ctx.potential_mode = PotentialMode.FORCE_FULL
    ctx.price_mode = PriceMode.CURRENT_ESTIMATE

    return ctx


static func for_run_review() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.RUN_REVIEW
    ctx.condition_mode = ConditionMode.FORCE_TRUE_VALUE
    ctx.potential_mode = PotentialMode.FORCE_FULL
    ctx.price_mode = PriceMode.SELL_PRICE
    return ctx


static func for_storage() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.STORAGE
    ctx.condition_mode = ConditionMode.FORCE_INSPECT_MAX
    ctx.potential_mode = PotentialMode.FORCE_FULL
    ctx.price_mode = PriceMode.SELL_PRICE
    return ctx
