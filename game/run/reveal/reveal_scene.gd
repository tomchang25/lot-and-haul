# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Marks uninspected items as inspected on reveal.
# One button press reveals ALL items at once instead of one-at-a-time.
# Reads:  RunManager.run_record.last_lot_won_items,
# Writes: ItemEntry.inspected, ItemEntry.scrutiny
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
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _won_items = RunManager.run_record.last_lot_won_items
    _continue_btn.hide()

    if _won_items.is_empty():
        _show_auction_lost_state()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    for entry: ItemEntry in _won_items:
        if entry.is_veiled():
            entry.unveil()

        entry.auto_reveal_all_surface()

    _on_reveal_complete()

    _reveal_btn.hide()
    _continue_btn.show()


func _on_continue_pressed() -> void:
    GameManager.go_to_lot_browse()


func _on_row_tooltip_requested(
        entry,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, anchor)

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(REVEAL_COLUMNS)
    _item_list_panel.populate(RunManager.run_record.last_lot_won_items)


func _show_auction_lost_state() -> void:
    _title_label.text = "Auction Lost"
    _item_list_panel.hide()
    _reveal_btn.hide()
    _continue_btn.show()


func _on_reveal_complete() -> void:
    _item_list_panel.rebuild_header()
    for entry in RunManager.run_record.last_lot_won_items:
        _item_list_panel.refresh_row(entry)
