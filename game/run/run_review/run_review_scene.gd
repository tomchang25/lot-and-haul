# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunSystem.run.location_data, RunSystem.run.cargo_items,
#         RunSystem.run.trailer_items, RunSystem.run.paid_price,
#         RunSystem.run.entry_fee, RunSystem.run.fuel_cost,
#         RunSystem.run.onsite_proceeds
# Writes: MetaSystem.economy.cash, MetaSystem.storage.storage_items
#         (via MetaSystem.resolve_current_run())
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const CASH_CREDITED: UiAudioEvent = preload("res://data/tres/audio_events/cash_credited.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")

const REVIEW_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.ESTIMATED_VALUE,
]

# ── Node references ───────────────────────────────────────────────────────────

@onready var _location_label: Label = %LocationLabel
@onready var _cargo_panel: CargoManifestPanel = %CargoPanel
@onready var _entry_fee_label: Label = %EntryFeeLabel
@onready var _fuel_cost_label: Label = %FuelCostLabel
@onready var _auction_paid_label: Label = %AuctionPaidLabel
@onready var _onsite_label: Label = %OnsiteLabel
@onready var _cash_flow_label: Label = %CashFlowLabel
@onready var _cargo_value_label: Label = %CargoValueLabel
@onready var _est_profit_label: Label = %EstProfitLabel
@onready var _continue_btn: Button = %ContinueButton
@onready var _tooltip: ItemCardPopup = %TooltipPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunSystem.run == null:
        ToastManager.show_error("Run review failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    RunSystem.set_resume_target(RunStore.RESUME_RUN_REVIEW)

    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.press_event = CONFIRM

    _cargo_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _cargo_panel.tooltip_dismissed.connect(_tooltip.request_hide)

    var loc := RunSystem.run.location_data
    if loc != null:
        _location_label.text = TranslationServer.translate(loc.display_name_key)
    else:
        _location_label.text = ""

    var cracked: int = RunSystem.apply_trailer_damage()
    _cargo_panel.set_damage_count(cracked)
    SaveManager.save()

    _populate_rows()
    _populate_finance()
    _cargo_panel.set_expanded(false)
    Director.register_scene(
        "run_review",
        {
            "cargo_panel": _cargo_panel,
            "continue_btn": _continue_btn,
        },
    )

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
    MetaSystem.resolve_current_run()
    EventBus.tutorial_event.emit(TutorialEvents.RUN_REVIEWED, { })
    AudioManager.play_event(CASH_CREDITED)
    SceneRouter.go_to_hub()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    var items: Array = RunSystem.run.cargo_items + RunSystem.run.trailer_items
    _cargo_panel.setup(REVIEW_COLUMNS, items)

# ══ Finance ledger ════════════════════════════════════════════════════════════


func _populate_finance() -> void:
    var run := RunSystem.run
    var entry_fee: int = run.entry_fee
    var fuel: int = run.fuel_cost
    var auction: int = run.paid_price
    var onsite: int = run.onsite_proceeds
    var cash_flow: int = onsite - entry_fee - fuel - auction

    _entry_fee_label.text = TranslationServer.translate("UI_ENTRY_FEE_LABEL") % (-entry_fee)

    var travel_days := run.location_data.travel_days if run.location_data != null else 0
    if travel_days > 0:
        _fuel_cost_label.text = TranslationServer.translate("UI_FUEL_MULTI_LABEL") % [travel_days, -fuel]
    else:
        _fuel_cost_label.text = TranslationServer.translate("UI_FUEL_LABEL") % (-fuel)

    _auction_paid_label.text = TranslationServer.translate("UI_PURCHASES_LABEL") % (-auction)
    _onsite_label.text = TranslationServer.translate("UI_ONSITE_LABEL") % onsite

    if cash_flow >= 0:
        _cash_flow_label.text = TranslationServer.translate("UI_CASH_FLOW_LABEL") % cash_flow
        _cash_flow_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.PRICE_COLOR)
    else:
        _cash_flow_label.text = TranslationServer.translate("UI_CASH_FLOW_LABEL") % cash_flow
        _cash_flow_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    var cargo_items: Array[ItemEntry] = run.cargo_items + run.trailer_items
    var estimate_price: int = 0
    for entry: ItemEntry in cargo_items:
        estimate_price += (entry.estimated_value_min + entry.estimated_value_max) / 2
    _cargo_value_label.text = TranslationServer.translate("UI_CARGO_VALUE_LABEL") % estimate_price

    var estimate_profit: int = cash_flow + estimate_price
    if estimate_profit >= 0:
        _est_profit_label.text = TranslationServer.translate("UI_EST_PROFIT_LABEL") % estimate_profit
        _est_profit_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _est_profit_label.text = TranslationServer.translate("UI_EST_PROFIT_LABEL") % estimate_profit
        _est_profit_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
