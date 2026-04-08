# item_card.gd
# Generalised item card for the inspection grid.
class_name ItemCard
extends PanelContainer

signal clicked(card: ItemCard)

var _entry: ItemEntry = null
var _ctx: ItemViewContext = null

@onready var _name_label: Label = $VBox/NameLabel
@onready var _super_category_label: Label = $VBox/SuperCategoryLabel
@onready var _category_label: Label = $VBox/CategoryLabel
@onready var _potential_label: Label = $VBox/PotentialLabel
@onready var _potential_price_row: Control = $VBox/PotentialPriceRow
@onready var _potential_price_label: Label = $VBox/PotentialPriceRow/PotentialPriceLabel
@onready var _condition_label: Label = $VBox/ConditionLabel
@onready var _condition_mult_label: Label = $VBox/ConditionMultLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _weight_label: Label = $VBox/WeightLabel
@onready var _grid_label:   Label = $VBox/GridLabel


func _ready() -> void:
    _apply()


func setup(entry: ItemEntry, ctx: ItemViewContext) -> void:
    _entry = entry
    _ctx = ctx

    if is_node_ready():
        _apply()


func refresh(changed: StringName = &"") -> void:
    _apply()
    match changed:
        &"potential":
            _animate_pop(_potential_label)
        &"condition":
            _animate_pop(_condition_label)


func _apply() -> void:
    _name_label.text = _entry.display_name

    # ── Category identity ─────────────────────────────────────────────────────
    if _entry.item_data != null and _entry.item_data.category_data != null:
        var cat := _entry.item_data.category_data
        if cat.super_category != null:
            _super_category_label.text = cat.super_category.display_name
            _super_category_label.visible = true
        else:
            _super_category_label.hide()
        _category_label.text = cat.display_name
        _category_label.visible = true
    else:
        _super_category_label.hide()
        _category_label.hide()

    # ── Inspection data ───────────────────────────────────────────────────────
    _potential_label.text = _entry.potential_label_for(_ctx)

    if _entry.should_show_potential_price_for(_ctx):
        _potential_price_label.text = _entry.potential_price_label
        _potential_price_row.show()
    else:
        _potential_price_row.hide()

    _condition_label.text = _entry.condition_label_for(_ctx)
    _condition_label.modulate = _entry.condition_color_for(_ctx)
    _condition_mult_label.text = _entry.condition_mult_label_for(_ctx)
    _price_label.text = _entry.price_label_for(_ctx)
    _price_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── Cargo stats ───────────────────────────────────────────────────────────
    if _entry.item_data != null and _entry.item_data.category_data != null:
        var cat := _entry.item_data.category_data
        var cell_count: int = cat.get_cells().size()
        _weight_label.text = "%.1f kg" % cat.weight
        _grid_label.text   = "%d slot%s  (%s)" % [
            cell_count,
            "s" if cell_count != 1 else "",
            cat.shape_id,
        ]
        _weight_label.show()
        _grid_label.show()
    else:
        _weight_label.hide()
        _grid_label.hide()


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
