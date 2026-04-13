# day_summary_scene.gd
# Standalone scene displaying day-advancement results (economics, actions).
# Both the hub day-pass flow and the run-review flow navigate here.
class_name DaySummaryScene
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _day_header: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DayHeader

@onready var _trip_group: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup
@onready var _onsite_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/OnsiteLabel
@onready var _entry_fee_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/EntryFeeLabel
@onready var _fuel_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/FuelLabel
@onready var _paid_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/PaidLabel

@onready var _living_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DailyGroup/LivingLabel
@onready var _actions_group: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DailyGroup/ActionsGroup
@onready var _actions_list: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DailyGroup/ActionsGroup/ActionsList

@onready var _cargo_count_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CargoCountLabel

@onready var _net_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/NetLabel
@onready var _balance_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/BalanceLabel

@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _continue_btn.pressed.connect(_on_continue_pressed)

    var summary: DaySummary = GameManager.consume_pending_day_summary()
    if summary == null:
        push_warning("DaySummaryScene: no pending summary — returning to hub")
        GameManager.go_to_hub()
        return

    _render(summary)

# ══ Display ═══════════════════════════════════════════════════════════════════


func _render(summary: DaySummary) -> void:
    # Day header
    if summary.days_elapsed > 1:
        _day_header.text = "Day %d → Day %d" % [summary.start_day, summary.end_day]
    else:
        _day_header.text = "Day %d" % summary.end_day

    # Trip group — visible only for run data
    _trip_group.visible = summary.has_run_data()
    if summary.has_run_data():
        _onsite_label.text = "Sold On-site:   $%d" % summary.onsite_proceeds
        _entry_fee_label.visible = summary.entry_fee != 0
        _entry_fee_label.text = "Entry Fee:   -$%d" % summary.entry_fee
        _fuel_label.visible = summary.fuel_cost != 0
        _fuel_label.text = "Fuel Cost:   -$%d" % summary.fuel_cost
        _paid_label.visible = summary.paid_price != 0
        _paid_label.text = "Amount Paid:   -$%d" % summary.paid_price

    # Daily group — always visible
    _living_label.text = "Living (%d/day × %d):   -$%d" % [
        Economy.DAILY_BASE_COST,
        summary.days_elapsed,
        summary.living_cost,
    ]

    # Completed actions
    for child in _actions_list.get_children():
        child.queue_free()
    _actions_group.visible = not summary.completed_actions.is_empty()
    for c: Dictionary in summary.completed_actions:
        var lbl := Label.new()
        lbl.text = "  · %s — %s" % [c.get("name", "?"), c.get("effect", "?")]
        lbl.add_theme_font_size_override("font_size", 16)
        _actions_list.add_child(lbl)

    # Cargo count
    _cargo_count_label.visible = summary.cargo_count > 0
    if summary.cargo_count == 1:
        _cargo_count_label.text = "Cargo brought back: 1 item"
    elif summary.cargo_count > 1:
        _cargo_count_label.text = "Cargo brought back: %d items" % summary.cargo_count

    # Net change + balance
    var net: int = summary.net_change
    if net >= 0:
        _net_label.text = "Net:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Net:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    _balance_label.text = "Balance:   $%d" % SaveManager.cash

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    GameManager.go_to_hub()
