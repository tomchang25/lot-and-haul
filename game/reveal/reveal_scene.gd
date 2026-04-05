# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Auto-advances layer 0 items to layer 1 on reveal. Player steps through each item.
# Reads:  GameManager.run_record.won_items
# Writes: (none — mutates ItemEntry.layer_index in place)
extends Control

# ── Exports ───────────────────────────────────────────────────────────────────

@export var _row_scene: PackedScene

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
var _reveal_index: int = 0
var _rows: Array[RevealItemRow] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _won_items = GameManager.run_record.last_lot_won_items
    _continue_btn.hide()

    if _won_items.is_empty():
        GameManager.go_to_location_browse()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    if _reveal_index >= _rows.size():
        return

    _rows[_reveal_index].reveal()
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
        var row: RevealItemRow = _row_scene.instantiate()
        _row_container.add_child(row)
        row.setup(entry)
        _rows.append(row)
