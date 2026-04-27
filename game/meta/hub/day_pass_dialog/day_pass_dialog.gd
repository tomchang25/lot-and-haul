# day_pass_dialog.gd
# Day-pass overlay: lets the player choose how many days to skip (1–7).
extends Control

signal confirmed(days: int)
signal cancelled

# ── Node references ──────────────────────────────────────────────────────────

@onready var _slider: HSlider = $CenterContainer/Panel/MarginContainer/VBox/SliderRow/DaysSlider
@onready var _days_label: Label = $CenterContainer/Panel/MarginContainer/VBox/SliderRow/DaysLabel
@onready var _cost_label: Label = $CenterContainer/Panel/MarginContainer/VBox/PreviewVBox/CostLabel
@onready var _balance_label: Label = $CenterContainer/Panel/MarginContainer/VBox/PreviewVBox/BalanceLabel
@onready var _confirm_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonRow/ConfirmButton
@onready var _cancel_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonRow/CancelButton

# ══ Lifecycle ════════════════════════════════════════════════════════════════


func _ready() -> void:
    visible = false
    _slider.value_changed.connect(_on_slider_changed)
    _confirm_btn.pressed.connect(_on_confirm_pressed)
    _cancel_btn.pressed.connect(_on_cancel_pressed)

# ══ Public API ═══════════════════════════════════════════════════════════════


func open() -> void:
    _slider.value = 1
    _refresh_preview()
    visible = true

# ══ Signal handlers ══════════════════════════════════════════════════════════


func _on_slider_changed(_value: float) -> void:
    _refresh_preview()


func _on_confirm_pressed() -> void:
    visible = false
    confirmed.emit(int(_slider.value))


func _on_cancel_pressed() -> void:
    visible = false
    cancelled.emit()

# ══ UI helpers ═══════════════════════════════════════════════════════════════


func _refresh_preview() -> void:
    var days: int = int(_slider.value)
    var cost: int = days * Economy.DAILY_BASE_COST
    var balance_after: int = SaveManager.cash - cost

    _days_label.text = "%d day(s)" % days
    _cost_label.text = "Living cost: $%d" % cost
    _balance_label.text = "Balance after: $%d" % balance_after

    var warn_color := Color(1.0, 0.3, 0.3, 1.0)
    var normal_color := Color(1.0, 1.0, 1.0, 1.0)
    _balance_label.add_theme_color_override(
        "font_color",
        warn_color if balance_after < 0 else normal_color,
    )
