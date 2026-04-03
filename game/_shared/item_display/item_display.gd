class_name ItemDisplay
extends PanelContainer

signal clicked(display: ItemDisplay)

var _entry: ItemEntry = null

# @onready var _sprite_rect: ColorRect = $VBox/SpriteRect
@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _potential_display: Label = $VBox/PotentialDisplay
@onready var _condition_display: Label = $VBox/ConditionDisplay


# Call after instantiation to bind entry and set initial display state.
func setup(entry: ItemEntry) -> void:
    _entry = entry
    _apply_layer()


# Called after entry.layer_index has been updated to sync the display and play the pop animation.
func refresh_display(changed: String = "") -> void:
    _apply_layer()
    match changed:
        "potential":
            _animate_pop(_potential_display)
        "condition":
            _animate_pop(_condition_display)


func _apply_layer() -> void:
    _name_label.text = _entry.display_name
    _price_label.text = _entry.price_estimate_label
    _potential_display.text = _entry.potential_inspect_label
    _condition_display.text = _entry.condition_inspect_label


func _animate_pop(target: Label) -> void:
    var tween := create_tween()
    tween.tween_property(target, "modulate", Color(1.0, 0.85, 0.15, 1.0), 0.08)
    tween.tween_property(target, "modulate", Color.WHITE, 0.25)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
        accept_event()
