# cargo_item_row.gd
# One selectable row in the Block 05 cargo checklist.
# Call setup() once after instantiation. Use set_toggle_disabled() to reflect
# limit state without the scene needing to know about CargoItemRow internals.
class_name CargoItemRow
extends PanelContainer

signal toggled(pressed: bool, item: ItemData)
@export var _toggle: CheckButton
@export var _name_lbl: Label
@export var _price_lbl: Label
@export var _weight_lbl: Label
@export var _size_lbl: Label

var item_data: ItemData = null

# ── Public API ────────────────────────────────────────────────────────────────


# Bind item data and populate all labels. Call once after add_child().
func setup(item: ItemData, inspection_level: int) -> void:
    item_data = item
    _name_lbl.text = item.item_name
    _price_lbl.text = ClueEvaluator.get_price_range_label(item, inspection_level)
    _weight_lbl.text = "%.1f kg" % item.weight
    _size_lbl.text = "%d" % item.grid_size
    _toggle.toggled.connect(_on_toggle_changed)


# Enable or disable the toggle. Selected rows are never disabled — the
# caller is responsible for checking _toggle.button_pressed before calling.
func set_toggle_disabled(value: bool) -> void:
    _toggle.disabled = value


func is_selected() -> bool:
    return _toggle.button_pressed

# ── Signal handler ────────────────────────────────────────────────────────────


func _on_toggle_changed(pressed: bool) -> void:
    toggled.emit(pressed, item_data)
