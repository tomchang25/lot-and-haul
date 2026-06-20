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
signal dice_toggled

# ── Constants ─────────────────────────────────────────────────────────────────

const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")
const CANCEL_EVENT: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const MAX_SELECTED_DICE := 2
const STRATEGY_CONSERVATIVE := "conservative"
const STRATEGY_AGGRESSIVE := "aggressive"

const DICE_ROLL_IN_DELAY_BASE := 0.08
const DICE_ROLL_IN_STAGGER := 0.07

# ── State ─────────────────────────────────────────────────────────────────────

enum OfferState { EMPTY_CAR, READY, ROLLING, SELECTING_DICE }

var _state: OfferState = OfferState.EMPTY_CAR
var _placed_items: Array = []
var _dice_rolls: Array[int] = []
var _selected_dice_indices: Array[int] = []
var _dice_buttons: Array[Button] = []
## External lock for flows that need to temporarily prevent conservative sales.
## The aggressive button is unaffected.
var _conservative_sale_locked: bool = false

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
@onready var _band_2_4: Label = %Band2_4
@onready var _band_5_9: Label = %Band5_9
@onready var _band_10_12: Label = %Band10_12
@onready var _pool_size_label: Label = %PoolSizeLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _conservative_button.pressed.connect(_on_conservative_pressed)
    _aggressive_button.pressed.connect(_on_aggressive_pressed)
    _confirm_dice_button.pressed.connect(_on_confirm_dice_pressed)
    _cancel_dice_button.pressed.connect(_on_cancel_dice_pressed)

# ══ Common API ════════════════════════════════════════════════════════════════


func set_placed_items(items: Array) -> void:
    _placed_items = items
    _update_state()


func disable_sell_buttons(disabled: bool) -> void:
    _conservative_button.disabled = disabled or _conservative_sale_locked
    _aggressive_button.disabled = disabled


## Locks conservative sale while preserving aggressive sale availability.
## Call again with [param locked] = false to restore normal behaviour.
func set_conservative_sale_locked(locked: bool) -> void:
    _conservative_sale_locked = locked
    if locked:
        _conservative_button.disabled = true


func show_dice(rolls: Array[int], placed_items: Array) -> void:
    _placed_items = placed_items
    _dice_rolls = rolls
    _selected_dice_indices.clear()
    _state = OfferState.ROLLING
    disable_sell_buttons(true)
    _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
    _dice_sum_label.text = "Sum: —"
    _dice_total_label.text = "Total: —"
    _confirm_dice_button.disabled = true
    _confirm_dice_button.hide()
    _cancel_dice_button.hide()
    _clear_band_highlights()
    _pool_size_label.text = "Rolling %d dice..." % rolls.size()
    _pool_size_label.show()
    _dice_section.show()
    _play_roll_in_animation()


func hide_dice() -> void:
    _dice_section.hide()
    _pool_size_label.hide()
    _state = OfferState.READY
    disable_sell_buttons(false)


func reset() -> void:
    _dice_section.hide()
    _pool_size_label.hide()
    _dice_rolls.clear()
    _selected_dice_indices.clear()
    _dice_buttons.clear()
    _placed_items.clear()
    _state = OfferState.EMPTY_CAR
    disable_sell_buttons(true)

# ══ Internal - State ════════════════════════════════════════════════════════════


func _update_state() -> void:
    if _placed_items.is_empty():
        _state = OfferState.EMPTY_CAR
        disable_sell_buttons(true)
    elif _state == OfferState.EMPTY_CAR:
        _state = OfferState.READY
        disable_sell_buttons(false)


func _play_roll_in_animation() -> void:
    _build_dice_buttons()
    _pool_size_label.hide()

    for i in _dice_buttons.size():
        var btn := _dice_buttons[i]
        btn.scale = Vector2.ZERO
        btn.modulate = Color(1, 1, 1, 0)
        var offset := DICE_ROLL_IN_DELAY_BASE + i * DICE_ROLL_IN_STAGGER
        var die_tween := create_tween().set_parallel(true)
        die_tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(offset)
        die_tween.tween_property(btn, "modulate", Color.WHITE, 0.08).set_delay(offset)

    var total_duration := DICE_ROLL_IN_DELAY_BASE + _dice_buttons.size() * DICE_ROLL_IN_STAGGER + 0.15
    var state_tween := create_tween()
    state_tween.tween_interval(total_duration)
    state_tween.tween_callback(
        func() -> void:
            for btn: Button in _dice_buttons:
                btn.scale = Vector2.ONE
            _state = OfferState.SELECTING_DICE
            _confirm_dice_button.show()
            _cancel_dice_button.show()
            _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
    )

# ══ Internal - Dice buttons ════════════════════════════════════════════════════


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
        _clear_band_highlights()
        return

    var sum := 0
    for index: int in _selected_dice_indices:
        sum += _dice_rolls[index]
    var multiplier := SellMath.dice_multiplier(sum)
    var total := SellMath.aggressive_total(_placed_items, sum)

    _dice_hint_label.text = ""
    _dice_sum_label.text = "Sum: %d (x%.1f)" % [sum, multiplier]
    _confirm_dice_button.disabled = false

    _highlight_band_for_sum(sum)
    _animate_total_to(total)


func _animate_total_to(target: int) -> void:
    var current: int = 0
    var raw_total := _dice_total_label.text
    if raw_total.begins_with("Total: $"):
        current = int(raw_total.trim_prefix("Total: $"))

    var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_method(
        func(val: float) -> void: _dice_total_label.text = "Total: $%d" % int(val),
        float(current),
        float(target),
        0.35,
    )


func _highlight_band_for_sum(sum: int) -> void:
    _clear_band_highlights()

    var bands := [
        [_band_2_4, 2, 4, Color(0.9, 0.3, 0.25)],
        [_band_5_9, 5, 9, Color(0.85, 0.75, 0.2)],
        [_band_10_12, 10, 12, Color(0.25, 0.85, 0.35)],
    ]
    for entry: Array in bands:
        var label: Label = entry[0]
        var lo: int = entry[1]
        var hi: int = entry[2]
        var col: Color = entry[3]
        if sum >= lo and sum <= hi:
            label.modulate = Color.WHITE
            label.add_theme_color_override(&"font_color", col)
            var tween := create_tween()
            tween.tween_property(label, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK)
            tween.tween_property(label, "scale", Vector2.ONE, 0.15)
        else:
            label.modulate = Color(0.5, 0.5, 0.5, 0.5)


func _clear_band_highlights() -> void:
    for band: Label in [_band_2_4, _band_5_9, _band_10_12]:
        band.modulate = Color(0.5, 0.5, 0.5, 0.5)
        band.scale = Vector2.ONE

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_conservative_pressed() -> void:
    if _placed_items.is_empty():
        return
    var price := SellMath.conservative_total(_placed_items)
    _play_glow(_conservative_button)
    conservative_requested.emit(price)


func _on_aggressive_pressed() -> void:
    if _placed_items.is_empty():
        return
    _play_glow(_aggressive_button)
    aggressive_requested.emit()


func _play_glow(button: Button) -> void:
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(button, "modulate", Color(1.3, 1.3, 0.6, 1.0), 0.08)
    tween.tween_property(button, "modulate", Color.WHITE, 0.18)


func _on_dice_toggled(index: int, toggled: bool) -> void:
    if index < 0 or index >= _dice_rolls.size() or index >= _dice_buttons.size():
        ToastManager.show_dev_error("DealPanel._on_dice_toggled: invalid dice index %d" % index)
        return

    if toggled:
        if _selected_dice_indices.size() >= MAX_SELECTED_DICE:
            _dice_buttons[index].button_pressed = false
            _play_reject_shake(_dice_buttons[index])
            return
        _selected_dice_indices.append(index)
        dice_toggled.emit()
    else:
        _selected_dice_indices.erase(index)

    _refresh_dice_totals()


func _play_reject_shake(button: Button) -> void:
    var original := button.position
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(button, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.06)
    tween.tween_property(button, "position", original + Vector2(3, 0), 0.03)
    tween.tween_property(button, "position", original - Vector2(3, 0), 0.03)
    tween.tween_property(button, "position", original + Vector2(1, 0), 0.03)
    tween.tween_property(button, "position", original, 0.03)
    tween.tween_property(button, "modulate", Color.WHITE, 0.1)


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
    _pool_size_label.hide()
    _state = OfferState.READY
    disable_sell_buttons(false)

    pitch_confirmed.emit(total)


func _on_cancel_dice_pressed() -> void:
    AudioManager.play_event(CANCEL_EVENT)
    _dice_section.hide()
    _pool_size_label.hide()
    _dice_rolls.clear()
    _selected_dice_indices.clear()
    _state = OfferState.READY
    disable_sell_buttons(false)
    _clear_band_highlights()
    dice_cancelled.emit()
