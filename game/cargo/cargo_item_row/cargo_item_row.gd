# cargo_item_row.gd
# One selectable row in the Block 05 cargo checklist.
# Call setup() once after instantiation. Use set_toggle_disabled() to reflect
# limit state without the scene needing to know about CargoItemRow internals.
class_name CargoItemRow
extends PanelContainer

signal toggled(pressed: bool, entry: ItemEntry)

# ── State ─────────────────────────────────────────────────────────────────────
var entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────
@onready var _toggle: CheckButton = $HBox/ToggleContainer/Toggle
@onready var _name_label: Label = $HBox/NameLabel
@onready var _level_label: Label = $HBox/LevelLabel
@onready var _condition_label: Label = $HBox/ConditionLabel
@onready var _price_label: Label = $HBox/PriceLabel
@onready var _weight_label: Label = $HBox/WeightLabel
@onready var _size_label: Label = $HBox/SizeLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed \
    and not _toggle.disabled:
        _toggle.button_pressed = !_toggle.button_pressed
        accept_event()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_toggle_changed(pressed: bool) -> void:
    toggled.emit(pressed, entry)

# ══ Common API ════════════════════════════════════════════════════════════════


# Bind entry and populate all labels. Call once after add_child().
func setup(p_entry: ItemEntry) -> void:
    entry = p_entry
    _toggle.toggled.connect(_on_toggle_changed)

    _name_label.text = entry.display_name
    _level_label.text = entry.potential_inspect_label
    _condition_label.text = entry.condition_inspect_label
    _condition_label.modulate = entry.condition_inspect_color
    _price_label.text = entry.player_estimate_label
    _weight_label.text = "%.1f kg" % entry.item_data.category_data.weight
    _size_label.text = "%d" % entry.item_data.category_data.grid_size


# Enable or disable the toggle. Selected rows are never disabled — the
# caller is responsible for checking _toggle.button_pressed before calling.
func set_toggle_disabled(value: bool) -> void:
    _toggle.disabled = value


func is_selected() -> bool:
    return _toggle.button_pressed
