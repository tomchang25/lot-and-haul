# value_row.gd
# A name-on-left, value-on-right label row used by item detail sidebars
# (Inspection, Storage, Customer Sell) for clue effect display, found list, and
# veiled list. The value label hides itself when given an empty string.
# Hovering over a clue or anchor row shows a detail tooltip via ClueTooltipManager.
class_name ValueRow
extends HBoxContainer

const Scene: PackedScene = preload("res://game/shared/item_display/value_row/value_row.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _name_text: String = ""
var _value_text: String = ""
var _value_color: Color = Color.WHITE
var _font_size: int = 13
var _separation: int = 8

var _clue: ClueData = null
var _anchor: AnchorData = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $NameLabel
@onready var _value_label: Label = $ValueLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    if _configured:
        _apply()

# ══ Static factory ════════════════════════════════════════════════════════════


## Creates a ValueRow for an anchor. When hovered, shows the anchor tooltip.
static func from_anchor(anchor_data: AnchorData) -> ValueRow:
    var row := Scene.instantiate()
    var label_text := TranslationServer.translate(anchor_data.known_text_key)
    var value_text := "$%d" % int(anchor_data.base_value)
    var value_color := ClueColors.ANCHOR_REVEALED_COLOR
    row.setup(label_text, value_text, value_color, 12, 4, anchor_data)
    return row


## Creates a ValueRow for a revealed clue. When hovered, shows the clue tooltip
## with attribute, DC, and price effect info.
static func from_clue(clue: ClueData) -> ValueRow:
    var row := Scene.instantiate()
    var label_text := TranslationServer.translate(clue.known_text_key)
    var value_text: String
    match clue.effect_op:
        "add":
            var prefix := "+" if clue.effect_amount >= 0 else ""
            value_text = "%s$%d" % [prefix, int(clue.effect_amount)]
        "mul":
            value_text = "x%.2f" % clue.effect_amount
        "override":
            value_text = "$%d" % int(clue.effect_amount)
    var value_color := ClueColors.for_effect_op(clue.effect_op, clue.effect_amount)
    row.setup(label_text, value_text, value_color, 12, 4, null, clue)
    return row

# ══ Common API ════════════════════════════════════════════════════════════════


## Configure the row. value_text == "" hides the value label (name-only row).
## [param anchor_data] and [param clue] are optional — when set, hovering over
## the row shows a detail tooltip via ClueTooltipManager.
func setup(
        name_text: String,
        value_text: String,
        value_color: Color,
        font_size: int = 13,
        separation: int = 8,
        anchor_data: AnchorData = null,
        clue: ClueData = null,
) -> void:
    _name_text = name_text
    _value_text = value_text
    _value_color = value_color
    _font_size = font_size
    _separation = separation
    _anchor = anchor_data
    _clue = clue
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

# ══ Tooltip ═══════════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    if _anchor != null:
        ClueTooltipManager.show_for_anchor(_anchor, get_global_rect(), true)
    elif _clue != null:
        ClueTooltipManager.show_for_clue(_clue, get_global_rect(), true)


func _on_mouse_exited() -> void:
    ClueTooltipManager.hide_tooltip()
