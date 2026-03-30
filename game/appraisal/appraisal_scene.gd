# appraisal_scene.gd
# Block 06 — Home Appraisal
# Reads:  GameManager.cargo_items, GameManager.lot_result
# Writes: GameManager.run_result
extends Control

# ── Exports ───────────────────────────────────────────────────────────────────

@export var _row_scene: PackedScene

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemData] = []
var _paid_price: int = 0
var _reveal_index: int = 0
var _rows: Array[AppraisalItemRow] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _summary_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/SummaryContainer
@onready var _sell_value_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/SellValueLabel
@onready var _paid_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/PaidLabel
@onready var _net_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/NetLabel
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _cargo_items = GameManager.cargo_items
    _paid_price = GameManager.lot_result.get(&"paid_price", 0)

    _populate_rows()

    if _cargo_items.is_empty():
        _reveal_btn.hide()
        _commit_result()
        _show_summary()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    if _reveal_index >= _rows.size():
        return

    _rows[_reveal_index].reveal()
    _reveal_index += 1

    if _reveal_index >= _rows.size():
        _commit_result()
        _show_summary()


func _on_continue_pressed() -> void:
    GameManager.go_to_warehouse_entry()

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if _cargo_items.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "You walked away empty-handed."
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_font_size_override(&"font_size", 16)
        empty_lbl.custom_minimum_size = Vector2(0, 60)
        _row_container.add_child(empty_lbl)
        return

    for item: ItemData in _cargo_items:
        _row_container.add_child(HSeparator.new())
        var row: AppraisalItemRow = _row_scene.instantiate()
        _row_container.add_child(row)
        row.setup(item)
        _rows.append(row)


func _commit_result() -> void:
    var sell_value: int = 0
    for item: ItemData in _cargo_items:
        sell_value += item.true_value
    GameManager.run_result = {
        &"sell_value": sell_value,
        &"paid_price": _paid_price,
        &"net": sell_value - _paid_price,
    }


func _show_summary() -> void:
    var r: Dictionary = GameManager.run_result
    var sell_value: int = r.get(&"sell_value", 0)
    var paid_price: int = r.get(&"paid_price", 0)
    var net: int = r.get(&"net", 0)

    _sell_value_label.text = "Total Sell Value:   $%d" % sell_value
    _paid_label.text = "Amount Paid:   $%d" % paid_price

    if net >= 0:
        _net_label.text = "Profit:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Loss:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    _summary_container.show()
    _continue_btn.show()
    _reveal_btn.hide()
