# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Marks uninspected items as inspected on reveal.
# One button press reveals ALL items at once instead of one-at-a-time.
# Reads:  RunManager.run_record.last_lot_won_objects,
#         RunManager.run_record.last_lot_won_commodities
# Writes: ItemEntry.inspected, ItemEntry.scrutiny,
#         CommodityEntry.sold, RunManager.run_record.commodity_sales
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const REVEAL_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
var _won_commodities: Array[CommodityEntry] = []
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_reveal()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _won_items = RunManager.run_record.last_lot_won_items
    _won_commodities = RunManager.run_record.last_lot_won_commodities
    _continue_btn.hide()

    if _won_items.is_empty() and _won_commodities.is_empty():
        GameManager.go_to_lot_browse()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    for entry: ItemEntry in _won_items:
        if entry.is_veiled():
            entry.unveil()

        entry.reveal()

    _sell_commodities()

    _on_reveal_complete()

    _reveal_btn.hide()
    _continue_btn.show()


func _on_continue_pressed() -> void:
    GameManager.go_to_lot_browse()


func _on_row_tooltip_requested(
        entry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(_ctx, REVEAL_COLUMNS)
    _item_list_panel.populate(RunManager.run_record.last_lot_won_objects)


func _sell_commodities() -> void:
    var sales := 0
    for commodity: CommodityEntry in _won_commodities:
        commodity.reveal()
        sales += commodity.mark_sold()
    RunManager.run_record.commodity_sales += sales


func _on_reveal_complete() -> void:
    _item_list_panel.rebuild_header()
    for entry in RunManager.run_record.last_lot_won_objects:
        _item_list_panel.refresh_row(entry)
