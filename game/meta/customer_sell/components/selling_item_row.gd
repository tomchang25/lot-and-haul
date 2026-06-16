# selling_item_row.gd
# Row component for the sellable item list — shows name, value, fit count, condition, and shape.
# Reads:  ItemEntry fields, SellMath utility
# Writes: nothing
class_name SellingItemRow
extends PanelContainer

signal row_pressed(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

# ── Constants ─────────────────────────────────────────────────────────────────

const SHAPE_CELL_SIZE := 6
const SHAPE_CELL_GAP := 1
const SHAPE_PADDING := 2

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _fit_count: int = 0
var _loaded: bool = false
var _hovered: bool = false
var _holding: bool = false
var _ext_highlighted: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _fit_label: Label = %FitLabel
@onready var _condition_label: Label = %ConditionLabel
@onready var _shape_icon: Control = %ShapeIcon

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)

    if _entry != null:
        _apply()
        _apply_state_style()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry, fit_count: int) -> void:
    _entry = entry
    _fit_count = fit_count

    if is_node_ready():
        _apply()
        _apply_state_style()


func refresh() -> void:
    if is_node_ready():
        _apply()
        _apply_state_style()


func set_loaded(loaded: bool) -> void:
    _loaded = loaded
    if is_node_ready():
        _apply_state_style()


func set_holding(val: bool) -> void:
    _holding = val
    if is_node_ready():
        _apply_state_style()


func set_external_highlight(val: bool) -> void:
    _ext_highlighted = val
    if is_node_ready():
        _apply_state_style()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        return

    _name_label.text = ItemEntryDisplayHelper.display_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    _value_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))

    _fit_label.text = "Fit: %d" % _fit_count

    _condition_label.text = ItemEntryDisplayHelper.condition_text(_entry)
    _condition_label.modulate = ItemEntryDisplayHelper.condition_display_color(_entry)

    _build_shape_icon()


func _apply_state_style() -> void:
    var style: StyleBox
    if _hovered or _ext_highlighted:
        style = get_theme_stylebox(&"hovered", &"SellingItemRow")
    elif _holding:
        style = get_theme_stylebox(&"holding", &"SellingItemRow")
    elif _loaded:
        style = get_theme_stylebox(&"loaded", &"SellingItemRow")
    else:
        style = get_theme_stylebox(&"default", &"SellingItemRow")
    add_theme_stylebox_override(&"panel", style)
    queue_redraw()
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _build_shape_icon() -> void:
    for child: Node in _shape_icon.get_children():
        _shape_icon.remove_child(child)
        child.queue_free()

    var cells: Array[Vector2i] = _entry.get_cells()
    if cells.is_empty():
        return

    var max_x := 0
    var max_y := 0
    for c: Vector2i in cells:
        if c.x > max_x:
            max_x = c.x
        if c.y > max_y:
            max_y = c.y

    var step := SHAPE_CELL_SIZE + SHAPE_CELL_GAP
    for c: Vector2i in cells:
        var rect := ColorRect.new()
        rect.size = Vector2(SHAPE_CELL_SIZE, SHAPE_CELL_SIZE)
        rect.position = Vector2(c.x * step + SHAPE_PADDING, c.y * step + SHAPE_PADDING)
        rect.color = Color(0.65, 0.65, 0.70, 1.0)

        # node-src: ephemeral — per-shape cell, rebuilt per refresh
        _shape_icon.add_child(rect)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    _hovered = true
    _apply_state_style()
    tooltip_requested.emit(_entry, get_global_rect())


func _on_mouse_exited() -> void:
    _hovered = false
    _apply_state_style()
    if not _ext_highlighted:
        tooltip_dismissed.emit()


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        row_pressed.emit(_entry)
        accept_event()
