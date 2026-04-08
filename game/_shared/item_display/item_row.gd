# item_row.gd
# Generalised item row used by list_review, reveal, cargo, and run_review.
# Collapsed state: Name | Base value | Condition mult | Estimate
#   + Weight | Grid   (cargo stage only, gated by ctx.show_cargo_stats)
# Hover: emits tooltip_requested for the parent scene to position and show.
class_name ItemRow
extends PanelContainer

signal tooltip_requested(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2)
signal tooltip_dismissed
signal row_pressed(entry: ItemEntry)

enum CargoState {
    NONE, # not in cargo stage — no override applied
    SELECTED, # loaded into cargo → white
    AVAILABLE, # can still be toggled → grey
    BLOCKED, # would exceed capacity → near-black
}

var _entry: ItemEntry = null
var _ctx: ItemViewContext = null
var _cargo_state: CargoState = CargoState.NONE

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


@onready var _name_label: Label = $HBoxContainer/NameLabel
@onready var _base_value_label: Label = $HBoxContainer/BaseValueLabel
@onready var _condition_mult_label: Label = $HBoxContainer/ConditionMultLabel
@onready var _estimate_label: Label = $HBoxContainer/EstimateLabel
@onready var _weight_label: Label = $HBoxContainer/WeightLabel
@onready var _grid_label: Label = $HBoxContainer/GridLabel


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

    _refresh()


func setup(entry: ItemEntry, ctx: ItemViewContext) -> void:
    _entry = entry
    _ctx = ctx

    if is_node_ready():
        _refresh()


func refresh() -> void:
    _refresh()


# Called by cargo_scene each time selection state changes.
# Applies background colour and enables/disables click handling.
func set_cargo_state(state: CargoState) -> void:
    _cargo_state = state
    _ensure_styles()

    match state:
        CargoState.SELECTED:
            add_theme_stylebox_override(&"panel", _style_selected)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        CargoState.AVAILABLE:
            add_theme_stylebox_override(&"panel", _style_available)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        CargoState.BLOCKED:
            add_theme_stylebox_override(&"panel", _style_blocked)
            mouse_default_cursor_shape = Control.CURSOR_ARROW
        CargoState.NONE:
            remove_theme_stylebox_override(&"panel")
            mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
    if _cargo_state == CargoState.NONE or _cargo_state == CargoState.BLOCKED:
        return
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        row_pressed.emit(_entry)
        accept_event()


func _refresh() -> void:
    if _entry == null:
        return

    _name_label.text = _entry.display_name

    if _entry.is_veiled():
        _base_value_label.text = "???"
    else:
        _base_value_label.text = "$%d" % _entry.active_layer().base_value

    _condition_mult_label.text = _entry.condition_label_for(_ctx)
    _condition_mult_label.modulate = _entry.condition_color_for(_ctx)

    _estimate_label.text = _entry.price_label_for(_ctx)
    _estimate_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── Cargo stats (weight / grid) ───────────────────────────────────────────
    var show_cargo: bool = _ctx != null and _ctx.show_cargo_stats
    _weight_label.visible = show_cargo
    _grid_label.visible = show_cargo

    if show_cargo and _entry.item_data != null and _entry.item_data.category_data != null:
        _weight_label.text = "%.1f kg" % _entry.item_data.category_data.weight
        _grid_label.text = "%d" % _entry.item_data.category_data.get_cells().size()


func _on_mouse_entered() -> void:
    tooltip_requested.emit(_entry, _ctx, get_global_rect())


func _on_mouse_exited() -> void:
    tooltip_dismissed.emit()
