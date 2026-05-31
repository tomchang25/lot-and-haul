# column_header_button.gd
# One clickable column header in ItemListPanel. Shows the column title plus a
# sort-direction arrow when it is the active sort column, and emits
# header_pressed(column) on click. The panel owns sort state and rebuilds.
class_name ColumnHeaderButton
extends Button

signal header_pressed(column: int)

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _column: int = 0
var _label_text: String = ""
var _is_sort_column: bool = false
var _ascending: bool = true
var _is_name_column: bool = false
var _min_width: float = 0.0

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    pressed.connect(func() -> void: header_pressed.emit(_column))
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(
        column: int,
        label_text: String,
        is_sort_column: bool,
        ascending: bool,
        is_name_column: bool,
        min_width: float,
) -> void:
    _column = column
    _label_text = label_text
    _is_sort_column = is_sort_column
    _ascending = ascending
    _is_name_column = is_name_column
    _min_width = min_width
    _configured = true
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    var text_out := _label_text
    if _is_sort_column:
        text_out += " ▲" if _ascending else " ▼"
    text = text_out

    if _is_name_column:
        size_flags_horizontal = Control.SIZE_EXPAND_FILL
        alignment = HORIZONTAL_ALIGNMENT_LEFT
    else:
        custom_minimum_size = Vector2(_min_width, 0)
        alignment = HORIZONTAL_ALIGNMENT_CENTER
