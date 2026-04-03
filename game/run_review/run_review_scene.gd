# run_review_scene.gd
# Block 06 — Run Review
# Reads:  GameManager.run_record.cargo_items, GameManager.run_record.paid_price,
#         GameManager.run_record.onsite_proceeds
# Writes: GameManager.run_record.sell_value, GameManager.run_record.net
extends Control

# ── Exports ───────────────────────────────────────────────────────────────────

@export var _row_scene: PackedScene

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _paid_price: int = 0

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _sell_value_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/SellValueLabel
@onready var _onsite_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/OnsiteLabel
@onready var _paid_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/PaidLabel
@onready var _net_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/NetLabel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _continue_btn.pressed.connect(_on_continue_pressed)

    _cargo_items = GameManager.run_record.cargo_items
    _paid_price = GameManager.run_record.paid_price

    _populate_rows()
    _commit_result()
    _show_summary()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    GameManager.clear_run_state()
    GameManager.go_to_warehouse_entry()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for entry: ItemEntry in _cargo_items:
        var row: RunReviewItemRow = _row_scene.instantiate()
        _row_container.add_child(row)
        row.setup(entry)

# ══ Result ════════════════════════════════════════════════════════════════════


func _commit_result() -> void:
    var sell_value: int = 0
    for entry: ItemEntry in _cargo_items:
        sell_value += int(entry.active_layer().base_value * entry.get_condition_multiplier())

    GameManager.run_record.sell_value = sell_value
    GameManager.run_record.net = sell_value + GameManager.run_record.onsite_proceeds - _paid_price


func _show_summary() -> void:
    var sell_value: int = GameManager.run_record.sell_value
    var onsite: int = GameManager.run_record.onsite_proceeds
    var net: int = GameManager.run_record.net

    _sell_value_label.text = "Total Sell Value:   $%d" % sell_value
    _onsite_label.text = "Sold On-site:   $%d" % onsite
    _paid_label.text = "Amount Paid:   $%d" % _paid_price

    if net >= 0:
        _net_label.text = "Profit:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Loss:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
