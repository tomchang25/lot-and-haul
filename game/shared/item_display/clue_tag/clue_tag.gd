# clue_tag.gd
# Reusable single-clue display: icon + name, color-coded by type/reveal state.
# Hover automatically shows ClueTooltip via the global ClueTooltipManager.
# Reads:  ClueData fields (type, known_text_key, effect fields)
# Writes: nothing
class_name ClueTag
extends HBoxContainer

# ── Constants ─────────────────────────────────────────────────────────────────

const SURFACE_ICON := "\u25cf"
const HIDDEN_ICON := "\u25c6"

# ── State ─────────────────────────────────────────────────────────────────────

var clue: ClueData:
    get:
        return _clue
var valued: bool:
    get:
        return _valued

var _clue: ClueData = null
var _revealed: bool = true
var _valued: bool = false

# ── Cached stylebox ───────────────────────────────────────────────────────────

var _valued_sb: StyleBoxFlat = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _icon_label: Label = %IconLabel
@onready var _name_label: Label = %NameLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    if _clue != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(data: ClueData, revealed: bool = true, p_valued: bool = false) -> void:
    _clue = data
    _revealed = revealed
    _valued = p_valued
    if is_node_ready():
        _apply()


func refresh() -> void:
    if is_node_ready():
        _apply()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    if _clue != null:
        ClueTooltipManager.show_for(_clue, get_global_rect(), _revealed, _valued)


func _on_mouse_exited() -> void:
    ClueTooltipManager.hide_tooltip()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _clue == null:
        return

    if _valued:
        _icon_label.text = "\u2605"
    elif _clue.type == ClueData.ClueType.SURFACE:
        _icon_label.text = SURFACE_ICON
    else:
        _icon_label.text = HIDDEN_ICON

    if _revealed:
        _name_label.text = TranslationServer.translate(_clue.known_text_key)
    else:
        _name_label.text = ItemEntryDisplayHelper.unknown_text()

    var color := ClueColors.for_clue(_clue, _revealed, _valued)
    _name_label.add_theme_color_override(&"font_color", color)
    _icon_label.add_theme_color_override(&"font_color", color)

    if _valued:
        add_theme_stylebox_override(&"panel", _valued_stylebox())
    else:
        remove_theme_stylebox_override(&"panel")


func _valued_stylebox() -> StyleBoxFlat:
    if _valued_sb == null:
        _valued_sb = StyleBoxFlat.new()
        _valued_sb.bg_color = Color(0.15, 0.12, 0.05)
        _valued_sb.border_color = ClueColors.VALUED_ACCENT
        _valued_sb.border_width_left = 1
        _valued_sb.border_width_right = 1
        _valued_sb.border_width_top = 1
        _valued_sb.border_width_bottom = 1
        _valued_sb.corner_radius_top_left = 3
        _valued_sb.corner_radius_top_right = 3
        _valued_sb.corner_radius_bottom_left = 3
        _valued_sb.corner_radius_bottom_right = 3
        _valued_sb.set_content_margin_all(2)
    return _valued_sb
