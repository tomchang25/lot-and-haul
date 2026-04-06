# item_row.gd
# Generalised item row used by list_review, reveal, cargo, and run_review.
# Collapsed state: Name | Base value | Condition mult | Estimate
# Hover: emits tooltip_requested for the parent scene to position and show.
class_name ItemRow
extends HBoxContainer

signal tooltip_requested(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2)
signal tooltip_dismissed

var _entry: ItemEntry = null
var _ctx: ItemViewContext = null

@onready var _name_label: Label = $NameLabel
@onready var _base_value_label: Label = $BaseValueLabel
@onready var _condition_mult_label: Label = $ConditionMultLabel
@onready var _estimate_label: Label = $EstimateLabel


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)


func setup(entry: ItemEntry, ctx: ItemViewContext) -> void:
    _entry = entry
    _ctx = ctx
    _refresh()


func refresh() -> void:
    _refresh()


func _refresh() -> void:
    _name_label.text = _entry.display_name

    if _entry.is_veiled():
        _base_value_label.text = "???"
    else:
        _base_value_label.text = "$%d" % _entry.active_layer().base_value

    _condition_mult_label.text = _entry.condition_mult_label_for(_ctx)
    _condition_mult_label.modulate = _entry.condition_color_for(_ctx)

    _estimate_label.text = _entry.price_label_for(_ctx)
    _estimate_label.add_theme_color_override(&"font_color", _entry.price_color)


func _on_mouse_entered() -> void:
    tooltip_requested.emit(_entry, _ctx, get_global_rect())


func _on_mouse_exited() -> void:
    tooltip_dismissed.emit()
