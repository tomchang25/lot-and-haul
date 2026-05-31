# value_row.gd
# A name-on-left, value-on-right label row used by the Inspection sidebar
# (found list, veiled list) and the clue breakdown. The value label hides
# itself when given an empty string, so callers needing name-only rows pass "".
class_name ValueRow
extends HBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _name_text: String = ""
var _value_text: String = ""
var _value_color: Color = Color.WHITE
var _font_size: int = 13
var _separation: int = 8

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $NameLabel
@onready var _value_label: Label = $ValueLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


## Configure the row. value_text == "" hides the value label (name-only row).
func setup(
        name_text: String,
        value_text: String,
        value_color: Color,
        font_size: int = 13,
        separation: int = 8,
) -> void:
    _name_text = name_text
    _value_text = value_text
    _value_color = value_color
    _font_size = font_size
    _separation = separation
    _configured = true
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    add_theme_constant_override(&"separation", _separation)

    _name_label.text = _name_text
    _name_label.add_theme_font_size_override(&"font_size", _font_size)

    _value_label.text = _value_text
    _value_label.add_theme_font_size_override(&"font_size", _font_size)
    _value_label.add_theme_color_override(&"font_color", _value_color)
    _value_label.visible = _value_text != ""
