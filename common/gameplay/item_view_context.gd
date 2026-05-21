# item_view_context.gd
# Describes the display context for a given stage.
# Pass one instance to ItemRow, ItemCard, and ItemRowTooltip.
# Condition and rarity labels read inspection_level directly on ItemEntry;
# this context only carries stage and side-channel data (merchant, order).
class_name ItemViewContext
extends RefCounted

enum Stage {
    INSPECTION,
    LIST_REVIEW,
    REVEAL,
    CARGO,
    RUN_REVIEW,
    STORAGE,
    MERCHANT_SHOP,
    FULFILLMENT_PANEL,
}

var stage: Stage
var merchant: MerchantData = null
var order: SpecialOrder = null

# ── Factories ─────────────────────────────────────────────────────────────────


static func for_inspection() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.INSPECTION
    return ctx


static func for_list_review() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.LIST_REVIEW
    return ctx


static func for_reveal() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.REVEAL
    return ctx


static func for_cargo() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.CARGO
    return ctx


static func for_run_review() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.RUN_REVIEW
    return ctx


static func for_storage() -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.STORAGE
    return ctx


static func for_merchant_shop(_merchant: MerchantData) -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.MERCHANT_SHOP
    ctx.merchant = _merchant
    return ctx


static func for_fulfillment(_order: SpecialOrder) -> ItemViewContext:
    var ctx := ItemViewContext.new()
    ctx.stage = Stage.FULFILLMENT_PANEL
    ctx.order = _order
    return ctx
