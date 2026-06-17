# deal_panel.gd
# Sell strategy panel — conservative quote, aggressive pitch state, dice tray, pending total.
# Reads:  SellMath, ItemEntry
# Writes: nothing
class_name DealPanel
extends PanelContainer

signal conservative_requested(price: int)
signal aggressive_requested
signal pitch_confirmed(price: int)
signal dice_cancelled

# ── Constants ─────────────────────────────────────────────────────────────────

const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")
const MAX_SELECTED_DICE := 2
const STRATEGY_CONSERVATIVE := "conservative"
const STRATEGY_AGGRESSIVE := "aggressive"

# ── State ─────────────────────────────────────────────────────────────────────

var _placed_items: Array = []
var _dice_rolls: Array[int] = []
var _selected_dice_indices: Array[int] = []
var _dice_buttons: Array[Button] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _conservative_button: SfxButton = %ConservativeButton
@onready var _aggressive_button: SfxButton = %AggressiveButton
@onready var _dice_section: VBoxContainer = %DiceSection
@onready var _dice_hint_label: Label = %DiceHint
@onready var _dice_row: HFlowContainer = %DiceRow
@onready var _dice_sum_label: Label = %DiceSumLabel
@onready var _dice_total_label: Label = %DiceTotalLabel
@onready var _confirm_dice_button: SfxButton = %ConfirmDiceButton
@onready var _cancel_dice_button: SfxButton = %CancelDiceButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _conservative_button.pressed.connect(_on_conservative_pressed)
    _aggressive_button.pressed.connect(_on_aggressive_pressed)
    _confirm_dice_button.pressed.connect(_on_confirm_dice_pressed)
    _cancel_dice_button.pressed.connect(_on_cancel_dice_pressed)

# ══ Common API ════════════════════════════════════════════════════════════════


func set_placed_items(items: Array) -> void:
    _placed_items = items


func disable_sell_buttons(disabled: bool) -> void:
    _conservative_button.disabled = disabled
    _aggressive_button.disabled = disabled


func show_dice(rolls: Array[int], placed_items: Array) -> void:
    _placed_items = placed_items
    _dice_rolls = rolls
    _selected_dice_indices.clear()
    _build_dice_buttons()
    _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
    _dice_sum_label.text = "Sum: —"
    _dice_total_label.text = "Total: —"
    _confirm_dice_button.disabled = true
    _dice_section.show()
    disable_sell_buttons(true)


func hide_dice() -> void:
    _dice_section.hide()
    disable_sell_buttons(false)


func reset() -> void:
    _dice_section.hide()
    _dice_rolls.clear()
    _selected_dice_indices.clear()
    _dice_buttons.clear()
    _placed_items.clear()
    disable_sell_buttons(false)

# ══ Internal ══════════════════════════════════════════════════════════════════


func _build_dice_buttons() -> void:
    _dice_buttons.clear()
    _clear_children(_dice_row)

    for index: int in _dice_rolls.size():
        var value := _dice_rolls[index]
        var button := SfxButton.new()
        button.custom_minimum_size = Vector2(44, 44)
        button.text = str(value)
        button.toggle_mode = true
        button.add_theme_font_size_override("font_size", 16)
        button.toggled.connect(func(toggled: bool) -> void: _on_dice_toggled(index, toggled))
        # node-src: ephemeral — per-die toggle, dynamic count
        _dice_row.add_child(button)
        _dice_buttons.append(button)


func _clear_children(container: Node) -> void:
    for child: Node in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _refresh_dice_totals() -> void:
    if _selected_dice_indices.size() != MAX_SELECTED_DICE:
        _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
        _dice_sum_label.text = "Sum: —"
        _dice_total_label.text = "Total: —"
        _confirm_dice_button.disabled = true
        return

    var sum := 0
    for index: int in _selected_dice_indices:
        sum += _dice_rolls[index]
    var multiplier := SellMath.dice_multiplier(sum)
    var total := SellMath.aggressive_total(_placed_items, sum)

    _dice_hint_label.text = ""
    _dice_sum_label.text = "Sum: %d (\u00d7%.1f)" % [sum, multiplier]
    _dice_total_label.text = "Total: $%d" % total
    _confirm_dice_button.disabled = false

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_conservative_pressed() -> void:
    if _placed_items.is_empty():
        return
    var price := SellMath.conservative_total(_placed_items)
    conservative_requested.emit(price)


func _on_aggressive_pressed() -> void:
    if _placed_items.is_empty():
        return
    aggressive_requested.emit()


func _on_dice_toggled(index: int, toggled: bool) -> void:
    if index < 0 or index >= _dice_rolls.size() or index >= _dice_buttons.size():
        ToastManager.show_dev_error("DealPanel._on_dice_toggled: invalid dice index %d" % index)
        return

    if toggled:
        if _selected_dice_indices.size() >= MAX_SELECTED_DICE:
            _dice_buttons[index].button_pressed = false
            return
        _selected_dice_indices.append(index)
    else:
        _selected_dice_indices.erase(index)

    _refresh_dice_totals()


func _on_confirm_dice_pressed() -> void:
    if _selected_dice_indices.size() != MAX_SELECTED_DICE:
        ToastManager.show_dev_error("DealPanel._on_confirm_dice_pressed: dice selection is incomplete")
        return
    if _placed_items.is_empty():
        ToastManager.show_dev_error("DealPanel._on_confirm_dice_pressed: no placed items")
        return

    var sum := 0
    for index: int in _selected_dice_indices:
        sum += _dice_rolls[index]
    var total := SellMath.aggressive_total(_placed_items, sum)

    AudioManager.play_event(CONFIRM)
    _dice_section.hide()
    disable_sell_buttons(false)

    pitch_confirmed.emit(total)


func _on_cancel_dice_pressed() -> void:
    _dice_section.hide()
    _dice_rolls.clear()
    _selected_dice_indices.clear()
    disable_sell_buttons(false)
    dice_cancelled.emit()
