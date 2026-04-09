# day_summary_panel.gd
# Shared display widget for DaySummary. Used by both DayPassPopup and
# RunReviewScene to present day-advancement results.
class_name DaySummaryPanel
extends VBoxContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _day_header: Label = $DayHeader

@onready var _income_group: VBoxContainer = $IncomeGroup
@onready var _onsite_label: Label = $IncomeGroup/OnsiteLabel

@onready var _living_label: Label = $ExpensesGroup/LivingLabel
@onready var _entry_fee_label: Label = $ExpensesGroup/EntryFeeLabel
@onready var _fuel_label: Label = $ExpensesGroup/FuelLabel
@onready var _paid_label: Label = $ExpensesGroup/PaidLabel

@onready var _actions_group: VBoxContainer = $ActionsGroup
@onready var _actions_list: VBoxContainer = $ActionsGroup/ActionsList

@onready var _net_label: Label = $NetLabel
@onready var _balance_label: Label = $BalanceLabel

# ══ Public API ════════════════════════════════════════════════════════════════


func show_summary(summary: DaySummary) -> void:
    # Day header
    if summary.days_elapsed > 1:
        _day_header.text = "Day %d → Day %d" % [summary.start_day, summary.end_day]
    else:
        _day_header.text = "Day %d" % summary.end_day

    # Income group — visible only for run data
    _income_group.visible = summary.has_run_data()
    if summary.has_run_data():
        _onsite_label.text = "Sold On-site:   $%d" % summary.onsite_proceeds

    # Expenses group — always visible
    _living_label.text = "Living (%d/day × %d):   -$%d" % [
        Economy.DAILY_BASE_COST,
        summary.days_elapsed,
        summary.living_cost,
    ]
    _entry_fee_label.visible = summary.entry_fee != 0
    _entry_fee_label.text = "Entry Fee:   -$%d" % summary.entry_fee
    _fuel_label.visible = summary.fuel_cost != 0
    _fuel_label.text = "Fuel Cost:   -$%d" % summary.fuel_cost
    _paid_label.visible = summary.paid_price != 0
    _paid_label.text = "Amount Paid:   -$%d" % summary.paid_price

    # Completed actions group
    for child in _actions_list.get_children():
        child.queue_free()
    _actions_group.visible = not summary.completed_actions.is_empty()
    for c: Dictionary in summary.completed_actions:
        var lbl := Label.new()
        lbl.text = "  · %s — %s" % [c.get("name", "?"), c.get("effect", "?")]
        lbl.add_theme_font_size_override("font_size", 16)
        _actions_list.add_child(lbl)

    # Net change + balance
    var net: int = summary.net_change
    if net >= 0:
        _net_label.text = "Net:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Net:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    _balance_label.text = "Balance:   $%d" % SaveManager.cash
