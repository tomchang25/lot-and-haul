# cargo_item_card.gd
# Grid card for displaying a won item in the cargo item list panel.
class_name CargoItemCard
extends PanelContainer

signal row_pressed(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

var _entry: ItemEntry = null
var _loaded: bool = false
var _hovered: bool = false
var _holding: bool = false
var _selected: bool = false
var _ext_highlighted: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _sprite_overlay: ItemSpriteOverlay = %SpriteOverlay


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)

    if _entry != null:
        _apply()
        _apply_state_style()


## Plays a brief yellow flash to signal the card was placed on the grid.
func play_loaded_pulse() -> void:
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self, "modulate", Color(1.4, 1.3, 0.5, 1.0), 0.08)
    tween.tween_property(self, "modulate", Color.WHITE, 0.22)


## Plays a red flash + horizontal shake to signal the item could not be placed.
func play_invalid_reject() -> void:
    var original := position
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.06)
    tween.tween_property(self, "position", original + Vector2(4, 0), 0.03)
    tween.tween_property(self, "position", original - Vector2(4, 0), 0.03)
    tween.tween_property(self, "position", original, 0.03)
    tween.tween_property(self, "modulate", Color.WHITE, 0.12)


## Sets the entry this card represents and applies visuals.
func setup(entry: ItemEntry) -> void:
    _entry = entry

    if is_node_ready():
        _apply()
        _apply_state_style()


## Re-applies the entry visuals and state style for when data changes externally.
func refresh() -> void:
    if is_node_ready():
        _apply()
        _apply_state_style()


## Marks the card as loaded (placed on grid or in a trailer slot) and updates style.
func set_loaded(loaded: bool) -> void:
    _loaded = loaded
    if is_node_ready():
        _apply_state_style()


## Marks the card as being actively held by the cursor.
func set_holding(val: bool) -> void:
    _holding = val
    if is_node_ready():
        _apply_state_style()


## Sets the card's selected state (highlighted as the currently active item).
func set_selected(val: bool) -> void:
    _selected = val
    if is_node_ready():
        _apply_state_style()


## Applies a highlight when the corresponding grid cell or trailer slot is hovered.
func set_external_highlight(val: bool) -> void:
    _ext_highlighted = val
    if is_node_ready():
        _apply_state_style()


func _apply() -> void:
    if _entry == null:
        return

    _sprite_overlay.setup(_entry, true)

    _name_label.text = ItemEntryDisplayHelper.short_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    _value_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))


func _apply_state_style() -> void:
    var style: StyleBox
    if _hovered or _ext_highlighted:
        style = get_theme_stylebox(&"hovered", &"CargoItemCard")
    elif _holding:
        style = get_theme_stylebox(&"holding", &"CargoItemCard")
    elif _selected:
        style = get_theme_stylebox(&"selected", &"CargoItemCard")
    elif _loaded:
        style = get_theme_stylebox(&"loaded", &"CargoItemCard")
    else:
        style = get_theme_stylebox(&"default", &"CargoItemCard")
    add_theme_stylebox_override(&"panel", style)
    queue_redraw()
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


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
