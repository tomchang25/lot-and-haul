class_name ItemDisplay
extends PanelContainer

signal clicked(display: ItemDisplay)

var item_data: ItemData = null
var inspection_level: int = 0

@onready var _sprite_rect: ColorRect = $VBox/SpriteRect
@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _level_label: Label = $VBox/LevelLabel


# Call after instantiation to bind item data and set initial display state.
func setup(item: ItemData, level: int) -> void:
    item_data = item
    _apply_level(level)


# Advance the item to a new inspection level and play the pop animation.
# Ignored if new_level is not higher than the current level.
func set_level(new_level: int) -> void:
    if new_level <= inspection_level:
        return
    _apply_level(new_level)
    _animate_level_pop()


func _apply_level(level: int) -> void:
    inspection_level = level
    _name_label.text = item_data.item_name
    _price_label.text = ClueEvaluator.get_price_range_label(item_data, level)
    _level_label.text = "Lvl %d" % level


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
