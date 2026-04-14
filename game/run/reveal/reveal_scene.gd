# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Auto-advances layer 0 items to layer 1 on reveal.
# One button press reveals ALL items at once instead of one-at-a-time.
# Reads:  RunManager.run_record.won_items
# Writes: (none — mutates ItemEntry.layer_index in place)
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const REVEAL_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.PRICE,
    ItemRow.Column.POTENTIAL,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
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
    _continue_btn.hide()

    if _won_items.is_empty():
        GameManager.go_to_lot_browse()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    for entry: ItemEntry in _won_items:
        entry.unveil()
        entry.condition_inspect_level = 2
        entry.potential_inspect_level = 2

    _on_reveal_complete()

    _reveal_btn.hide()
    _continue_btn.show()


func _on_continue_pressed() -> void:
    GameManager.go_to_lot_browse()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(_ctx, REVEAL_COLUMNS)
    _item_list_panel.populate(_won_items)


func _on_reveal_complete() -> void:
    _ctx.condition_mode = ItemViewContext.ConditionMode.FORCE_INSPECT_MAX
    _ctx.potential_mode = ItemViewContext.PotentialMode.FORCE_FULL
    _ctx.price_mode = ItemViewContext.PriceMode.ESTIMATED_VALUE

    _item_list_panel.rebuild_header()
    for entry: ItemEntry in _won_items:
        _item_list_panel.refresh_row(entry)
