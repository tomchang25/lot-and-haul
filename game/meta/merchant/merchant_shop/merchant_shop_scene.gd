# merchant_shop_scene.gd
# Merchant Shop — Select storage items and negotiate a basket sale.
# Reads:  SaveManager.storage_items, SaveManager.cash, GameManager (merchant hand-off)
# Writes: SaveManager.storage_items, SaveManager.cash
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")
const NegotiationDialogScene: PackedScene = preload(
    "res://game/meta/merchant/negotiation_dialog/negotiation_dialog.tscn"
)

const SHOP_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.MERCHANT_OFFER,
    ItemRow.Column.MARKET_FACTOR,
    ItemRow.Column.RARITY,
    ItemRow.Column.INSPECTION,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _merchant: MerchantData = null
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected: Dictionary = { } # ItemEntry → bool
var _negotiation_dialog: Control = null
var _research_warning_dialog: ConfirmationDialog = null
var _pending_basket: Array[ItemEntry] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _pricing_info_label: Label = $RootVBox/PricingInfoLabel
@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _sell_btn: Button = $RootVBox/Footer/SellButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel
@onready var _trade_summary_popup: AcceptDialog = $TradeSummaryPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _merchant = GameManager.consume_pending_merchant()
    _ctx = ItemViewContext.for_merchant_shop(_merchant)
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _title_label.text = _merchant.display_name if _merchant else "Merchant"
    _populate_pricing_info()

    _back_btn.pressed.connect(_on_back_pressed)
    _sell_btn.pressed.connect(_on_sell_pressed)
    _trade_summary_popup.confirmed.connect(_on_trade_summary_dismissed)
    _trade_summary_popup.canceled.connect(_on_trade_summary_dismissed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _research_warning_dialog = ConfirmationDialog.new()
    _research_warning_dialog.confirmed.connect(_on_research_warning_confirmed)
    add_child(_research_warning_dialog)

    _populate_rows()
    _refresh_sell_button()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_merchant_hub()


func _on_row_pressed(entry: ItemEntry) -> void:
    _selected[entry] = not _selected.get(entry, false)
    var row: ItemRow = _item_list_panel.get_row(entry)
    if row != null:
        row.set_selection_state(
            ItemRow.SelectionState.SELECTED if _selected[entry] else ItemRow.SelectionState.AVAILABLE,
        )
    _refresh_sell_button()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)


func _on_sell_pressed() -> void:
    var basket: Array[ItemEntry] = []
    for entry: ItemEntry in _selected:
        if _selected[entry]:
            basket.append(entry)
    if basket.is_empty():
        return

    var researched_lines: PackedStringArray = []
    for entry: ItemEntry in basket:
        var action: String = ResearchSlot.action_for_item(SaveManager.research_slots, entry.id)
        if action != "":
            researched_lines.append("• %s (%s)" % [entry.display_name, action])

    if not researched_lines.is_empty():
        _pending_basket = basket
        _research_warning_dialog.dialog_text = (
            "The following items are currently being researched:\n%s\n\nSelling will cancel their research. Continue?"
            % "\n".join(researched_lines)
        )
        _research_warning_dialog.popup_centered()
        return

    _open_negotiation(basket)


func _on_research_warning_confirmed() -> void:
    _open_negotiation(_pending_basket)
    _pending_basket = []


func _open_negotiation(basket: Array[ItemEntry]) -> void:
    if _negotiation_dialog == null:
        _negotiation_dialog = NegotiationDialogScene.instantiate()
        add_child(_negotiation_dialog)
        _negotiation_dialog.accepted.connect(_on_negotiation_accepted)
        _negotiation_dialog.cancelled.connect(_on_negotiation_cancelled)

    _negotiation_dialog.begin(_merchant, basket)


func _on_negotiation_accepted(final_price: int) -> void:
    var sold: Array[ItemEntry] = []
    for entry: ItemEntry in _selected:
        if _selected[entry]:
            sold.append(entry)

    MetaManager.sell_items(sold, final_price, _merchant)

    _trade_summary_popup.dialog_text = "Sold %d item%s for $%d." % [
        sold.size(),
        "" if sold.size() == 1 else "s",
        final_price,
    ]
    _trade_summary_popup.popup_centered()


func _on_trade_summary_dismissed() -> void:
    GameManager.go_to_merchant_hub()


func _on_negotiation_cancelled() -> void:
    MerchantRegistry.increment_negotiation(_merchant)
    SaveManager.save()
    GameManager.go_to_merchant_hub()

# ══ Pricing info ══════════════════════════════════════════════════════════════


func _populate_pricing_info() -> void:
    if _merchant.accepted_super_categories.size() > 0:
        var names: Array[String] = []
        for sc: SuperCategoryData in _merchant.accepted_super_categories:
            names.append(sc.display_name)
        var lines: PackedStringArray = PackedStringArray()
        lines.append("Main: %s" % ", ".join(names))
        lines.append("Price: \u00d7%.2f" % _merchant.price_multiplier)
        if _merchant.accepts_off_category:
            lines.append(
                "Other: \u00d7%.2f" % (_merchant.price_multiplier * _merchant.off_category_multiplier),
            )
        _pricing_info_label.text = "\n".join(lines)
    elif _merchant.accepts_off_category:
        _pricing_info_label.text = (
            "Accepts: All\nPrice: \u00d7%.2f"
            % (_merchant.price_multiplier * _merchant.off_category_multiplier)
        )
    else:
        push_error(
            "merchant_shop_scene: merchant '%s' has no accepted_super_categories and accepts_off_category=false"
            % _merchant.merchant_id,
        )

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    var buyable: Array[ItemEntry] = []
    for entry: ItemEntry in SaveManager.storage_items:
        if _merchant.offer_for(entry) > 0:
            buyable.append(entry)

    if buyable.is_empty():
        _empty_label.visible = true
        _item_list_panel.visible = false
        _sell_btn.disabled = true
        return

    _empty_label.visible = false
    _item_list_panel.visible = true

    _item_list_panel.setup(_ctx, SHOP_COLUMNS)
    _item_list_panel.populate(buyable)

    for entry: ItemEntry in buyable:
        _selected[entry] = false
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

# ══ UI state ══════════════════════════════════════════════════════════════════


func _refresh_sell_button() -> void:
    var any_selected: bool = false
    for entry: ItemEntry in _selected:
        if _selected[entry]:
            any_selected = true
            break
    _sell_btn.disabled = not any_selected
