# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Auto-advances layer 0 items to layer 1 on reveal. Player steps through each item.
# Reads:  RunManager.run_record.won_items
# Writes: (none — mutates ItemEntry.layer_index in place)
extends Control

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
var _reveal_index: int = 0
var _rows: Array[ItemRow] = []
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_reveal()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _won_items = RunManager.run_record.last_lot_won_items
    _continue_btn.hide()

    if _won_items.is_empty():
        GameManager.go_to_location_browse()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    if _reveal_index >= _rows.size():
        return

    var entry: ItemEntry = _won_items[_reveal_index]
    if entry.is_veiled():
        entry.layer_index = 1
    entry.condition_inspect_level = 2
    entry.potential_inspect_level = 2
    _rows[_reveal_index].refresh()

    _reveal_index += 1

    if _reveal_index >= _rows.size():
        _reveal_btn.hide()
        _continue_btn.show()


func _on_continue_pressed() -> void:
    GameManager.go_to_location_browse()

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for entry: ItemEntry in _won_items:
        _row_container.add_child(HSeparator.new())
        var row: ItemRow = ItemRowScene.instantiate()
        _row_container.add_child(row)
        row.setup(entry, _ctx)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)
        _rows.append(row)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)
