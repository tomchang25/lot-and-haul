class_name ActionPopup
extends PanelContainer

signal potential_inspect_requested
signal condition_inspect_requested
signal cancelled

const POTENTIAL_COST := 2
const CONDITION_COST := 2

@onready var _potential_button: Button = $HBoxContainer/PotentialButton
@onready var _condition_button: Button = $HBoxContainer/ConditionButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton


func _ready() -> void:
    _potential_button.pressed.connect(_on_potential_pressed)
    _condition_button.pressed.connect(_on_condition_pressed)
    _cancel_button.pressed.connect(_on_cancel_pressed)


# Update button state based on the entry's current unlock action and available stamina.
func refresh(entry: ItemEntry, stamina: int) -> void:
    # Potential button
    var p_maxed := entry.potential_inspect_level >= 2 or entry.is_veiled()
    _potential_button.disabled = p_maxed or stamina < POTENTIAL_COST
    _potential_button.text = "Inspect Potential (%d SP)" % POTENTIAL_COST
    if entry.is_veiled():
        _potential_button.text = "Veiled"
    elif entry.potential_inspect_level >= 2:
        _potential_button.text = "Potential: Max"

    # Condition button
    var c_locked := not entry.is_condition_inspectable()
    var c_maxed := entry.condition_inspect_level >= 2
    _condition_button.disabled = c_maxed or c_locked or stamina < CONDITION_COST
    if c_maxed:
        _condition_button.text = "Condition: Max"
    elif entry.is_veiled():
        _condition_button.text = "Condition: Veiled"
    elif c_locked:
        _condition_button.text = "Condition: Too Damaged"
    else:
        _condition_button.text = "Inspect Condition (%d SP)" % CONDITION_COST


func _on_potential_pressed() -> void:
    potential_inspect_requested.emit()


func _on_condition_pressed() -> void:
    condition_inspect_requested.emit()


func _on_cancel_pressed() -> void:
    cancelled.emit()
