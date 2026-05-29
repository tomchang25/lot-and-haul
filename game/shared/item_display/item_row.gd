# item_row.gd
# Generalised item row used by list_review, reveal, run_review, storage,
# and pawn_shop.
# Column visibility and order are driven by the columns array passed to setup().
# Hover: emits tooltip_requested for the parent scene to position and show.
class_name ItemRow
extends PanelContainer

signal tooltip_requested(entry, anchor: Rect2)
signal tooltip_dismissed
signal row_pressed(entry)

# ── Enums ─────────────────────────────────────────────────────────────────────

enum SelectionState {
    NONE, # no override applied
    SELECTED, # selected → white
    AVAILABLE, # can still be toggled → grey
    BLOCKED, # would exceed capacity → near-black
}

enum Column {
    NAME,
    CONDITION,
    ESTIMATED_VALUE,
    BASE_VALUE,
    RARITY,
    WEIGHT,
    GRID,
    INSPECTION,
}

# ── Constants ─────────────────────────────────────────────────────────────────

const COLUMN_HEADERS: Dictionary = {
    Column.NAME: "Item",
    Column.CONDITION: "Condition",
    Column.ESTIMATED_VALUE: "Est. Value",
    Column.BASE_VALUE: "Base Value",
    Column.RARITY: "Rarity",
    Column.WEIGHT: "Weight",
    Column.GRID: "Grid",
    Column.INSPECTION: "Inspection",
}

const COLUMN_MIN_WIDTH: Dictionary = {
    Column.NAME: 0,
    Column.CONDITION: 120,
    Column.ESTIMATED_VALUE: 160,
    Column.BASE_VALUE: 160,
    Column.RARITY: 120,
    Column.WEIGHT: 100,
    Column.GRID: 80,
    Column.INSPECTION: 100,
}

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _columns: Array = []
var _selection_state: SelectionState = SelectionState.NONE

# ── Node references ───────────────────────────────────────────────────────────

@onready var _h_box_container: HBoxContainer = $HBoxContainer
@onready var _name_cell: HBoxContainer = $HBoxContainer/NameHBox
@onready var _name_label: Label = $HBoxContainer/NameHBox/NameLabel
@onready var _condition_label: Label = $HBoxContainer/ConditionLabel
@onready var _estimated_value_label: Label = $HBoxContainer/EstimatedValueLabel
@onready var _base_value_label: Label = $HBoxContainer/BaseValueLabel
@onready var _rarity_label: Label = $HBoxContainer/RarityLabel
@onready var _weight_label: Label = $HBoxContainer/WeightLabel
@onready var _grid_label: Label = $HBoxContainer/GridLabel
@onready var _inspection_label: Label = $HBoxContainer/InspectionLabel
@onready var _auth_tag_label: Label = $HBoxContainer/NameHBox/AuthTagLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

    _refresh()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry, columns: Array = []) -> void:
    _entry = entry
    _columns = columns

    if is_node_ready():
        _refresh()


func refresh() -> void:
    _refresh()


# Called by consuming scenes to apply row selection styling.
# Applies background colour and enables/disables click handling.
func set_selection_state(state: SelectionState) -> void:
    _selection_state = state
    _ensure_styles()

    match state:
        SelectionState.SELECTED:
            add_theme_stylebox_override(&"panel", _style_selected)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        SelectionState.AVAILABLE:
            add_theme_stylebox_override(&"panel", _style_available)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        SelectionState.BLOCKED:
            add_theme_stylebox_override(&"panel", _style_blocked)
            mouse_default_cursor_shape = Control.CURSOR_ARROW
        SelectionState.NONE:
            remove_theme_stylebox_override(&"panel")
            mouse_default_cursor_shape = Control.CURSOR_ARROW
        _:
            push_warning("Unknown SelectionState: %d" % state)


static func get_price_header() -> String:
    return "Est. Value"

# ══ Input ═════════════════════════════════════════════════════════════════════


func _gui_input(event: InputEvent) -> void:
    if _selection_state == SelectionState.NONE or _selection_state == SelectionState.BLOCKED:
        return
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        row_pressed.emit(_entry)
        accept_event()

# ══ Refresh ═══════════════════════════════════════════════════════════════════


func _refresh() -> void:
    if _entry == null:
        return

    # ── Column visibility ─────────────────────────────────────────────────────
    _name_cell.visible = Column.NAME in _columns
    _condition_label.visible = Column.CONDITION in _columns
    _estimated_value_label.visible = Column.ESTIMATED_VALUE in _columns
    _base_value_label.visible = Column.BASE_VALUE in _columns
    _rarity_label.visible = Column.RARITY in _columns
    _weight_label.visible = Column.WEIGHT in _columns
    _grid_label.visible = Column.GRID in _columns
    _inspection_label.visible = Column.INSPECTION in _columns

    # ── Column order ──────────────────────────────────────────────────────────
    _apply_column_order()

    # ── NAME ──────────────────────────────────────────────────────────────────
    _name_label.text = _entry.display_name
    _name_label.add_theme_color_override(&"font_color", _entry.display_name_color())

    var item_entry := _entry as ItemEntry
    _auth_tag_label.visible = Column.NAME in _columns \
    and item_entry != null \
    and item_entry.verified

    # ── CONDITION ─────────────────────────────────────────────────────────────
    _condition_label.text = _entry.condition_text()
    _condition_label.modulate = _entry.condition_display_color()

    # ── ESTIMATED_VALUE ────────────────────────────────────────────────────────
    _estimated_value_label.text = _entry.estimated_value_text()
    _estimated_value_label.add_theme_color_override(&"font_color", _entry.price_display_color())

    # ── BASE_VALUE ─────────────────────────────────────────────────────────────
    _base_value_label.text = _entry.base_value_text()
    _base_value_label.add_theme_color_override(&"font_color", _entry.price_display_color())

    # ── RARITY ────────────────────────────────────────────────────────────────
    _rarity_label.text = _entry.rarity_text()

    # ── WEIGHT / GRID ─────────────────────────────────────────────────────────
    _weight_label.text = _entry.weight_text()
    _grid_label.text = _entry.grid_text()

    # ── INSPECTION ────────────────────────────────────────────────────────────
    _inspection_label.text = _entry.inspection_text()

# ══ Column ordering ═══════════════════════════════════════════════════════════


func _apply_column_order() -> void:
    if _columns.is_empty() or not is_node_ready():
        return

    var column_to_label: Dictionary = {
        Column.NAME: _name_cell,
        Column.CONDITION: _condition_label,
        Column.ESTIMATED_VALUE: _estimated_value_label,
        Column.BASE_VALUE: _base_value_label,
        Column.RARITY: _rarity_label,
        Column.WEIGHT: _weight_label,
        Column.GRID: _grid_label,
        Column.INSPECTION: _inspection_label,
    }

    for i in _columns.size():
        var col: Column = _columns[i]
        if column_to_label.has(col):
            _h_box_container.move_child(column_to_label[col], i)

# ══ Selection styles ══════════════════════════════════════════════════════════

# Built once on demand and reused across all rows.
static var _style_selected: StyleBoxFlat = null
static var _style_available: StyleBoxFlat = null
static var _style_blocked: StyleBoxFlat = null


static func _ensure_styles() -> void:
    if _style_selected != null:
        return

    _style_selected = StyleBoxFlat.new()
    _style_selected.bg_color = Color(1.0, 1.0, 1.0, 0.15) # white tint

    _style_available = StyleBoxFlat.new()
    _style_available.bg_color = Color(0.5, 0.5, 0.5, 0.15) # grey tint

    _style_blocked = StyleBoxFlat.new()
    _style_blocked.bg_color = Color(0.08, 0.08, 0.08, 0.9) # near-black

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    tooltip_requested.emit(_entry, get_global_rect())


func _on_mouse_exited() -> void:
    tooltip_dismissed.emit()
