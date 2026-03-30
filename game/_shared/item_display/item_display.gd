class_name ItemDisplay
extends PanelContainer

signal clicked(display: ItemDisplay)

var _entry: ItemEntry = null

@onready var _sprite_rect: ColorRect = $VBox/SpriteRect
@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _level_label: Label = $VBox/LevelLabel


# Call after instantiation to bind entry and set initial display state.
func setup(entry: ItemEntry) -> void:
    _entry = entry
    _apply_level()


# Called after entry.inspection_level has been updated to sync the display and play the pop animation.
func refresh_display() -> void:
    _apply_level()
    _animate_level_pop()


func _apply_level() -> void:
    if _entry.is_veiled():
        _name_label.text = _entry.resolved_veiled_type.display_label
    else:
        _name_label.text = _entry.item_data.item_name

    _price_label.text = ClueEvaluator.get_price_range_label(_entry)
    _level_label.text = InspectionRules.level_label(_entry.inspection_level)


func _animate_level_pop() -> void:
    var tween := create_tween()
    tween.tween_property(_level_label, "modulate", Color(1.0, 0.85, 0.15, 1.0), 0.08)
    tween.tween_property(_level_label, "modulate", Color.WHITE, 0.25)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
        accept_event()
