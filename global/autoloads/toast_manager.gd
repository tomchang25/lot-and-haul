# toast_manager.gd
# Lightweight overlay for player-visible notifications. Purely code-built —
# no .tscn. Creates a high-layer CanvasLayer with a VBoxContainer anchored
# to the top-center of the screen.
#
# API:
#   show_warning(message)   — always shown, regardless of Debug mode (corruption alerts).
#   show_info(message)      — shown only when Debug.enabled (migration alerts).
#   show_error(message)     — always shown, red (runtime errors); also logs via push_error.
#   show_dev_error(message) — logs via push_error ("[DEV] " prefix); toast only when Debug.enabled.
#
# All error logging goes through show_error / show_dev_error — bare push_error
# at call sites is forbidden (error_guard_standard.md). This file is the single
# lint-exempt home of push_error.
extends Node

const _WARN_DURATION := 6.0
const _INFO_DURATION := 4.0
const _ERROR_DURATION := 8.0
const _FADE_DURATION := 0.4

const _COLOR_WARNING := Color(0.95, 0.75, 0.3) # warning_yellow
const _COLOR_INFO := Color(0.88, 0.88, 0.92, 1.0) # primary text
const _COLOR_ERROR := Color(0.95, 0.35, 0.3, 1.0) # error_red

const _BG_COLOR := Color(0.15, 0.15, 0.18, 1.0) # panel surface
const _BORDER_COLOR := Color(0.3, 0.3, 0.35, 1.0) # 1px border

const _CHANNEL_WARNING := "warning"
const _CHANNEL_INFO := "info"
const _CHANNEL_ERROR := "error"
const _CHANNEL_DEV_ERROR := "dev_error"

var _canvas: CanvasLayer
var _stack: VBoxContainer

## Session-unique set of messages that have already been toasted by channel.
## Prevents toast spam from per-frame/loop guards. Cleared on restart.
var _toasted_messages: Dictionary = { }


func _ready() -> void:
    _canvas = CanvasLayer.new()
    _canvas.layer = 128
    add_child(_canvas)

    _stack = VBoxContainer.new()
    _stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _stack.custom_minimum_size = Vector2(400.0, 0.0)
    _stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _stack.add_theme_constant_override("separation", 6)
    _canvas.add_child(_stack)

    # Position top-center with a small margin.
    _stack.position = Vector2(
        (DisplayServer.window_get_size().x - 400.0) / 2.0,
        16.0,
    )


## Shows a warning toast. Always visible regardless of Debug.enabled.
## Use for corruption-fallback alerts.
func show_warning(message: String) -> void:
    _push_toast(message, _COLOR_WARNING, _WARN_DURATION, _CHANNEL_WARNING)


## Shows an info toast. Only visible when Debug.enabled is true.
## Use for migration detail alerts.
func show_info(message: String) -> void:
    if not Debug.enabled:
        return
    _push_toast(message, _COLOR_INFO, _INFO_DURATION, _CHANNEL_INFO)


## Shows an error toast. Always visible regardless of Debug.enabled.
## Use for runtime error fallback alerts (scene entry guards, etc.).
##
## Also writes the message to the error log via push_error, so player-reported
## runtime errors leave a trail in release exports. Do not add a separate
## push_error at the call site. Include context in the message (system name,
## operation) — the log's reported location points here, not at the guard.
func show_error(message: String) -> void:
    push_error(message)
    _push_toast(message, _COLOR_ERROR, _ERROR_DURATION, _CHANNEL_ERROR)


## One-call programmer-error guard: always writes [param message] to the error
## log (reachable in release exports, prefixed "[DEV] " to distinguish bugs
## from runtime errors in player-reported logs) and shows a red error toast on
## screen, but only when the debug gate is enabled — players never see internal
## detail.
##
## Toasts are deduped fire-once per session: a guard sitting in a per-frame or
## loop path produces at most one toast per unique message string, while every
## occurrence still reaches the error log.
##
## Usage:
##     func spend(amount: int) -> bool:
##         if amount < 0:
##             ToastManager.show_dev_error("spend() expects non-negative amount, got %d" % amount)
##             return false
func show_dev_error(message: String) -> void:
    push_error("[DEV] " + message)
    if not Debug.enabled:
        return
    _push_toast(message, _COLOR_ERROR, _ERROR_DURATION, _CHANNEL_DEV_ERROR)


func _push_toast(message: String, color: Color, duration: float, channel: String) -> void:
    var toast_key := "%s:%s" % [channel, message]
    if _toasted_messages.has(toast_key):
        return
    _toasted_messages[toast_key] = true

    var panel := PanelContainer.new()

    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = _BG_COLOR
    stylebox.border_color = _BORDER_COLOR
    stylebox.set_border_width_all(1)
    stylebox.set_corner_radius_all(4)
    stylebox.content_margin_left = 12.0
    stylebox.content_margin_right = 12.0
    stylebox.content_margin_top = 8.0
    stylebox.content_margin_bottom = 8.0
    panel.add_theme_stylebox_override("panel", stylebox)

    var label := Label.new()
    label.text = message
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", 14)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(376.0, 0.0)

    panel.add_child(label)
    panel.modulate.a = 0.0
    _stack.add_child(panel)

    var tween := create_tween()
    tween.set_parallel(false)
    # Fade in.
    tween.tween_property(panel, "modulate:a", 1.0, _FADE_DURATION)
    # Hold.
    tween.tween_interval(duration)
    # Fade out.
    tween.tween_property(panel, "modulate:a", 0.0, _FADE_DURATION)
    # Remove.
    tween.tween_callback(panel.queue_free)
