# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunManager.run_record.cargo_items, RunManager.run_record.paid_price,
#         RunManager.run_record.onsite_proceeds
# Writes: RunManager.run_record.sell_value, RunManager.run_record.net,
#         SaveManager.cash, SaveManager.storage_items
extends Control

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _paid_price: int = 0
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _onsite_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/OnsiteLabel
@onready var _paid_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/PaidLabel
@onready var _net_label: Label = $RootVBox/ListCenter/OuterVBox/SummaryContainer/NetLabel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_run_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _continue_btn.pressed.connect(_on_continue_pressed)

    _cargo_items = RunManager.run_record.cargo_items
    _paid_price = RunManager.run_record.paid_price

    _populate_rows()
    _commit_result()
    _show_summary()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    SaveManager.cash += RunManager.run_record.net
    for entry: ItemEntry in RunManager.run_record.cargo_items:
        SaveManager.storage_items.append(entry)
    SaveManager.save()
    RunManager.clear_run_state()
    GameManager.go_to_hub()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for entry: ItemEntry in _cargo_items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)

        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

        _row_container.add_child(row)

# ══ Result ════════════════════════════════════════════════════════════════════


func _commit_result() -> void:
    RunManager.run_record.net = RunManager.run_record.onsite_proceeds - _paid_price


func _show_summary() -> void:
    var onsite: int = RunManager.run_record.onsite_proceeds
    var net: int = RunManager.run_record.net

    _onsite_label.text = "Sold On-site:   $%d" % onsite
    _paid_label.text = "Amount Paid:   $%d" % _paid_price

    if net >= 0:
        _net_label.text = "Gain:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Loss:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)
