# day_summary_scene.gd
# Standalone scene displaying day-advancement results (economics, actions).
# Both the hub day-pass flow and the run-review flow navigate here.
class_name DaySummaryScene
extends Control

# ── Constants ───────────────────────────────────────────────────────────

const CASH_CREDITED: UiAudioEvent = preload("res://data/tres/audio_events/cash_credited.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _day_header: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DayHeader

@onready var _trip_group: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup
@onready var _onsite_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/OnsiteLabel
@onready var _entry_fee_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/EntryFeeLabel
@onready var _fuel_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/FuelLabel
@onready var _paid_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/TripGroup/PaidLabel

@onready var _customer_group: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CustomerSalesGroup
@onready var _conservative_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CustomerSalesGroup/ConservativeLabel
@onready var _aggressive_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CustomerSalesGroup/AggressiveLabel
@onready var _customer_total_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CustomerSalesGroup/CustomerTotalLabel

@onready var _living_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/DailyGroup/LivingLabel

@onready var _cargo_group: VBoxContainer = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CargoGroup
@onready var _cargo_count_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/CargoGroup/CargoCountLabel

@onready var _net_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/NetLabel
@onready var _balance_label: Label = $RootVBox/PanelCenter/OuterPanel/Margin/ContentVBox/BalanceLabel

@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.press_event = CONFIRM

    var summary: DaySummary = SceneRouter.consume_pending_day_summary()
    if summary == null:
        ToastManager.show_warning("DaySummaryScene: no pending summary — returning to hub")
        SceneRouter.go_to_hub()
        return

    _render(summary)
    Director.register_scene(
        "day_summary",
        {
            "continue_btn": _continue_btn,
        },
    )

# ══ Display ═══════════════════════════════════════════════════════════════════


func _render(summary: DaySummary) -> void:
    # Day header
    if summary.days_elapsed > 1:
        _day_header.text = TranslationServer.translate("UI_DAY_TO_DAY") % [summary.start_day, summary.end_day]
    else:
        _day_header.text = TranslationServer.translate("UI_DAY_LABEL") % summary.end_day

    # Trip group — visible only for run data
    _trip_group.visible = summary.has_run_data()
    if summary.has_run_data():
        _onsite_label.text = TranslationServer.translate("UI_SOLD_ONSITE_LABEL") % summary.onsite_proceeds
        _entry_fee_label.visible = summary.entry_fee != 0
        _entry_fee_label.text = TranslationServer.translate("UI_ENTRY_FEE_DEBIT") % summary.entry_fee
        _fuel_label.visible = summary.fuel_cost != 0
        _fuel_label.text = TranslationServer.translate("UI_FUEL_COST_DEBIT") % summary.fuel_cost
        _paid_label.visible = summary.paid_price != 0
        _paid_label.text = TranslationServer.translate("UI_AMOUNT_PAID") % summary.paid_price

    # Customer sales section
    _customer_group.visible = summary.has_customer_sales()
    if summary.has_customer_sales():
        var cons_count := 0
        var cons_total := 0
        var agg_count := 0
        var agg_total := 0
        for sale in summary.customer_sales_detail:
            if sale.strategy == "conservative":
                cons_count += sale.item_count
                cons_total += sale.sale_price
            elif sale.strategy == "aggressive":
                agg_count += sale.item_count
                agg_total += sale.sale_price
        _conservative_label.text = TranslationServer.translate("UI_CONSERVATIVE_SUMMARY") % [cons_count, cons_total]
        _aggressive_label.text = TranslationServer.translate("UI_AGGRESSIVE_SUMMARY") % [agg_count, agg_total]
        _customer_total_label.text = TranslationServer.translate("UI_TOTAL_CUSTOMER_SALES") % summary.customer_sales_total

    # Daily group — always visible
    _living_label.text = TranslationServer.translate("UI_LIVING_COST") % summary.living_cost

    # Cargo count
    _cargo_group.visible = summary.cargo_count > 0
    if summary.cargo_count > 0:
        _cargo_count_label.text = TranslationServer.translate("UI_CARGO_BACK") % summary.cargo_count

    # Net change + balance
    var net: int = summary.net_change
    if net >= 0:
        _net_label.text = TranslationServer.translate("UI_NET_CREDIT") % net
        _net_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.PRICE_COLOR)
        AudioManager.play_event(CASH_CREDITED)
    else:
        _net_label.text = TranslationServer.translate("UI_NET_DEBIT") % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    _balance_label.text = TranslationServer.translate("UI_BALANCE_LABEL") % MetaManager.economy.cash

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    EventBus.tutorial_event.emit(TutorialEvents.DAY_SUMMARY_CONTINUED, { })
    SceneRouter.go_to_hub()
