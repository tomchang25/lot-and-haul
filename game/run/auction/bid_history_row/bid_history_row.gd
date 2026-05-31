# bid_history_row.gd
# One line in the auction bid history ("YOU -- $N" or "Bidder X -- $N").
# Owns its own lifetime animation: play_enter_and_expire() (NPC bids fade in,
# hold, fade out) or play_expire() (the player's own line holds, then frees).
class_name BidHistoryRow
extends Label

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _line_text: String = ""
var _font_color: Color = Color.WHITE
var _apply_color: bool = false

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


## apply_color == false leaves the theme's default font color (used for NPC bids).
func setup(line_text: String, font_color: Color = Color.WHITE, apply_color: bool = false) -> void:
    _line_text = line_text
    _font_color = font_color
    _apply_color = apply_color
    _configured = true
    if is_node_ready():
        _apply()


## NPC bid: fade in, hold, fade out, free. Call after add_child().
func play_enter_and_expire() -> void:
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.15)
    tween.tween_interval(3.0)
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    tween.tween_callback(queue_free)


## Player bid: hold, then free. Call after add_child().
func play_expire() -> void:
    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_callback(queue_free)

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    text = _line_text
    if _apply_color:
        add_theme_color_override(&"font_color", _font_color)
