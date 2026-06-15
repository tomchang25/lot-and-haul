# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunManager.run.cargo_items, RunManager.run.trailer_items, RunManager.run.car_data,
#         RunManager.run.paid_price, RunManager.run.entry_fee, RunManager.run.fuel_cost,
#         RunManager.run.onsite_proceeds
# Writes: MetaManager.economy.cash, MetaManager.storage.storage_items (via MetaManager.resolve_current_run())
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const CASH_CREDITED: UiAudioEvent = preload("res://data/tres/audio_events/cash_credited.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")

const REVIEW_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _review_entries: Array = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _cost_cash_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/CostCashLabel
@onready var _finance_onsite_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/OnsiteLabel
@onready var _overall_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/OverallLabel
@onready var _estimate_price_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/EstimatePriceLabel
@onready var _estimate_profit_label: Label = $RootVBox/FinanceCenter/FinancePanel/FinanceMargin/FinanceVBox/EstimateProfitLabel
@onready var _trailer_damage_label: Label = $RootVBox/ListCenter/OuterVBox/TrailerDamageLabel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton
@onready var _tooltip: ItemCardPopup = %TooltipPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.run == null:
        ToastManager.show_error("Run review failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.press_event = CONFIRM

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_popup)

    var cracked: int = RunManager.apply_trailer_damage()
    if cracked > 0:
        _trailer_damage_label.text = "%d trailer item(s) cracked during transport" % cracked
        _trailer_damage_label.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.3))
        _trailer_damage_label.visible = true

    _cargo_items = RunManager.run.cargo_items + RunManager.run.trailer_items
    _review_entries = []
    _review_entries.append_array(_cargo_items)

    _populate_rows()
    _populate_finance()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    _resolve_run_and_navigate()


func _on_row_tooltip_requested(
        entry,
        anchor: Rect2,
) -> void:
    if entry is ItemEntry:
        _tooltip.show_for(entry as ItemEntry, anchor)

# ══ Run resolution ════════════════════════════════════════════════════════════


func _resolve_run_and_navigate() -> void:
    # resolve_run stashes run economics as pending and sets current_slot = 3
    # (player returns for the evening slot). The day summary fires later when
    # the player chooses Open Shop or exhausts all slots from the hub.
    MetaManager.resolve_current_run()
    AudioManager.play_event(CASH_CREDITED)
    SceneRouter.go_to_hub()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(REVIEW_COLUMNS)
    _item_list_panel.populate(_review_entries)


func _populate_finance() -> void:
    var cost_cash: int = RunManager.run.paid_price + RunManager.run.entry_fee + RunManager.run.fuel_cost
    var onsite: int = RunManager.run.onsite_proceeds
    var overall: int = onsite - cost_cash

    _cost_cash_label.text = "Cost Cash:   -$%d" % cost_cash
    _finance_onsite_label.text = "Sold On-site:   +$%d" % onsite

    if overall >= 0:
        _overall_label.text = "Cash Flow:   +$%d" % overall
        _overall_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.PRICE_COLOR)
    else:
        _overall_label.text = "Cash Flow:   -$%d" % (-overall)
        _overall_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    var estimate_price: int = 0
    for entry: ItemEntry in _cargo_items:
        estimate_price += (entry.estimated_value_min + entry.estimated_value_max) / 2
    _estimate_price_label.text = "Est. Cargo Value:   $%d" % estimate_price

    var estimate_profit: int = overall + estimate_price
    if estimate_profit >= 0:
        _estimate_profit_label.text = "Est. Profit:   +$%d" % estimate_profit
        _estimate_profit_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _estimate_profit_label.text = "Est. Profit:   -$%d" % (-estimate_profit)
        _estimate_profit_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
