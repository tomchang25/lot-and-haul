# item_card.gd
# Generalised item card for the inspection grid.
class_name ItemCard
extends PanelContainer

signal clicked(card: ItemCard)

var _entry: ItemEntry = null
var _is_selected: bool = false
var _has_intuition_mark: bool = false

@onready var _name_label: Label = $VBox/NameLabel
@onready var _super_category_label: Label = $VBox/SuperCategoryLabel
@onready var _category_label: Label = $VBox/CategoryLabel
@onready var _potential_label: Label = $VBox/PotentialLabel
@onready var _condition_label: Label = $VBox/ConditionLabel
@onready var _condition_mult_label: Label = $VBox/ConditionMultLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _weight_label: Label = $VBox/WeightLabel
@onready var _grid_label: Label = $VBox/GridLabel


func _ready() -> void:
    _apply()


func setup(entry) -> void:
    _entry = entry

    if is_node_ready():
        _apply()


func refresh(changed: StringName = &"") -> void:
    _apply()
    match changed:
        &"potential":
            _animate_pop(_potential_label)
        &"condition":
            _animate_pop(_condition_label)
        &"unveil":
            _animate_pop(_name_label)


func _apply() -> void:
    if _entry == null:
        return

    _name_label.text = _entry.display_name

    if _entry.is_veiled():
        _apply_unknown()
    else:
        _apply_known()


func _apply_unknown() -> void:
    # Uninspected rows must not depend on legacy layer-0 veil data.
    _super_category_label.hide()
    _category_label.hide()
    _potential_label.hide()
    _condition_label.hide()
    _condition_mult_label.hide()
    _weight_label.hide()
    _grid_label.hide()

    _price_label.text = "???"
    _price_label.add_theme_color_override(&"font_color", _entry.price_display_color())
    _price_label.show()


func _apply_known() -> void:
    var super_category := _entry.super_category_text()
    if super_category != "":
        _super_category_label.text = super_category
        _super_category_label.show()
    else:
        _super_category_label.hide()

    var category := _entry.category_text()
    if category != "":
        _category_label.text = category
        _category_label.show()
    else:
        _category_label.hide()

    _potential_label.text = _entry.rarity_text()
    _potential_label.show()

    _condition_label.text = _entry.condition_text()
    _condition_label.modulate = _entry.condition_display_color()
    _condition_label.show()

    var condition_secondary := _entry.condition_secondary_text()
    if condition_secondary != "":
        _condition_mult_label.text = condition_secondary
        _condition_mult_label.show()
    else:
        _condition_mult_label.hide()

    _price_label.text = _entry.estimated_value_text()
    _price_label.add_theme_color_override(&"font_color", _entry.price_display_color())
    _price_label.show()

    var weight := _entry.weight_text()
    var grid := _entry.grid_text()
    if weight != ItemEntry.UNKNOWN_TEXT:
        _weight_label.text = weight
        _weight_label.show()
    else:
        _weight_label.hide()
    if grid != ItemEntry.UNKNOWN_TEXT:
        _grid_label.text = grid
        _grid_label.show()
    else:
        _grid_label.hide()


func _animate_pop(target: Label) -> void:
    var tween := create_tween()
    tween.tween_property(target, "modulate", Color(1.0, 0.85, 0.15, 1.0), 0.08)
    tween.tween_property(target, "modulate", Color.WHITE, 0.25)


func flash_border() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.6, 1.4, 0.6, 1.0), 0.08)
    tween.tween_property(self, "modulate", Color.WHITE, 0.22)


func _draw() -> void:
    if _is_selected:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 1.0, 0.10))
    if _has_intuition_mark:
        draw_rect(Rect2(Vector2(size.x - 12.0, 4.0), Vector2(8.0, 8.0)), Color(1.0, 0.85, 0.2, 0.9))


func set_selected(selected: bool) -> void:
    _is_selected = selected
    queue_redraw()


func play_intuition_shimmer() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.3, 1.1, 0.4, 1.0), 0.1)
    tween.tween_property(self, "modulate", Color.WHITE, 0.4)
    tween.tween_callback(
        func() -> void:
            _has_intuition_mark = true
            queue_redraw()
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
        accept_event()
