# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunManager.run_record.cargo_items, RunManager.run_record.paid_price,
#         RunManager.run_record.onsite_proceeds
# Writes: SaveManager.cash, SaveManager.storage_items
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const REVIEW_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.RARITY,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _cost_cash_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/CostCashLabel
@onready var _finance_onsite_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/OnsiteLabel
@onready var _overall_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/OverallLabel
@onready var _estimate_price_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/EstimatePriceLabel
@onready var _estimate_profit_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/EstimateProfitLabel
@onready var _trailer_damage_label: Label = $RootVBox/ListCenter/OuterVBox/TrailerDamageLabel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_run_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _continue_btn.pressed.connect(_on_continue_pressed)

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    var cracked := _apply_trailer_damage()
    if cracked > 0:
        _trailer_damage_label.text = "%d trailer item(s) cracked during transport" % cracked
        _trailer_damage_label.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.3))
        _trailer_damage_label.visible = true

    _cargo_items = RunManager.run_record.cargo_items + RunManager.run_record.trailer_items

    _populate_rows()
    _populate_finance()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    _resolve_run_and_navigate()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)

# ══ Trailer damage ════════════════════════════════════════════════════════════


func _apply_trailer_damage() -> int:
    var r := RunManager.run_record
    var car := r.car_data
    if car.trailer_damage_chance <= 0.0:
        return 0

    var cracked := 0
    for entry: ItemEntry in r.trailer_items:
        if randf() < car.trailer_damage_chance:
            var ratio := randf_range(car.trailer_damage_ratio_min, car.trailer_damage_ratio_max)
            entry.condition = maxf(0.0, entry.condition - ratio)
            cracked += 1
    return cracked

# ══ Run resolution ════════════════════════════════════════════════════════════


func _resolve_run_and_navigate() -> void:
    var summary := MetaManager.resolve_run(RunManager.run_record)
    GameManager.go_to_day_summary(summary)

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(_ctx, REVIEW_COLUMNS)
    _item_list_panel.populate(_cargo_items)


func _populate_finance() -> void:
    var r := RunManager.run_record
    var cost_cash := r.paid_price + r.entry_fee + r.fuel_cost
    var onsite := r.onsite_proceeds
    var overall := onsite - cost_cash

    _cost_cash_label.text = "Cost Cash:   -$%d" % cost_cash
    _finance_onsite_label.text = "Sold On-site:   +$%d" % onsite

    if overall >= 0:
        _overall_label.text = "Cash Flow:   +$%d" % overall
        _overall_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _overall_label.text = "Cash Flow:   -$%d" % (-overall)
        _overall_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    var estimate_price: int = 0
    for entry: ItemEntry in _cargo_items:
        estimate_price += entry.compute_price(ItemRegistry.price_config_with_estimated)
    _estimate_price_label.text = "Est. Cargo Value:   $%d" % estimate_price

    var estimate_profit := overall + estimate_price
    if estimate_profit >= 0:
        _estimate_profit_label.text = "Est. Profit:   +$%d" % estimate_profit
        _estimate_profit_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _estimate_profit_label.text = "Est. Profit:   -$%d" % (-estimate_profit)
        _estimate_profit_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
