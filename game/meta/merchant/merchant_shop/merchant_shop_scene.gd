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
    ItemRow.Column.PRICE,
    ItemRow.Column.MARKET_FACTOR,
    ItemRow.Column.POTENTIAL,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _merchant: MerchantData = null
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected: Dictionary = { } # ItemEntry → bool
var _negotiation_dialog: Control = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _sell_btn: Button = $RootVBox/Footer/SellButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _merchant = GameManager.consume_pending_merchant()
    _ctx = ItemViewContext.for_merchant_shop(_merchant)
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _title_label.text = _merchant.display_name if _merchant else "Merchant"

    _back_btn.pressed.connect(_on_back_pressed)
    _sell_btn.pressed.connect(_on_sell_pressed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

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

    SaveManager.cash += final_price
    for entry: ItemEntry in sold:
        SaveManager.storage_items.erase(entry)
        KnowledgeManager.add_category_points(
            entry.item_data.category_data.category_id,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )

    MerchantRegistry.increment_negotiation(_merchant)
    SaveManager.save()
    GameManager.go_to_merchant_hub()


func _on_negotiation_cancelled() -> void:
    MerchantRegistry.increment_negotiation(_merchant)
    SaveManager.save()
    GameManager.go_to_merchant_hub()

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
