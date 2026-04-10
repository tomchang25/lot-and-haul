class_name ActionPopup
extends PanelContainer

signal potential_inspect_requested
signal condition_inspect_requested
signal xray_inspect_requested
signal cancelled

const POTENTIAL_COST := 2
const CONDITION_COST := 2
const XRAY_COST := 3

@onready var _potential_button: Button = $HBoxContainer/PotentialButton
@onready var _condition_button: Button = $HBoxContainer/ConditionButton
@onready var _xray_button: Button = $HBoxContainer/XrayButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton


func _ready() -> void:
    _potential_button.pressed.connect(_on_potential_pressed)
    _condition_button.pressed.connect(_on_condition_pressed)
    _xray_button.pressed.connect(_on_xray_pressed)
    _cancel_button.pressed.connect(_on_cancel_pressed)

    _potential_button.disabled = _is_potential_action_disabled()
    _condition_button.disabled = _is_condition_action_disabled()


# Update button state based on the entry's current unlock action and available stamina.
func refresh(entry: ItemEntry) -> void:
    # Potential button
    var p_maxed := entry.potential_inspect_level >= 2 or entry.is_veiled()
    _potential_button.disabled = p_maxed or _is_potential_action_disabled()
    if entry.is_veiled():
        _potential_button.text = "Veiled"
    elif entry.potential_inspect_level >= 2:
        _potential_button.text = "Potential: Max"
    elif entry.potential_inspect_level == 1:
        _potential_button.text = "Inspect Potential Lv2 (%d SP)" % POTENTIAL_COST
    else:
        _potential_button.text = "Inspect Potential (%d SP)" % POTENTIAL_COST

    # Condition button
    var c_locked := not entry.is_condition_inspectable()
    var c_maxed := entry.condition_inspect_level >= 2
    _condition_button.disabled = c_maxed or c_locked or _is_condition_action_disabled()
    if c_maxed:
        _condition_button.text = "Condition: Max"
    elif entry.is_veiled():
        _condition_button.text = "Condition: Veiled"
    elif c_locked:
        _condition_button.text = "Condition: Too Damaged"
    else:
        _condition_button.text = "Inspect Condition (%d SP)" % CONDITION_COST

    # X-Ray button — only shown for veiled items when the perk is unlocked.
    var xray_visible := entry.is_veiled() and KnowledgeManager.has_perk("xray_inspect")
    _xray_button.visible = xray_visible
    if xray_visible:
        _xray_button.text = "X-Ray Scan (%d SP)" % XRAY_COST
        _xray_button.disabled = _is_xray_action_disabled()


func _on_potential_pressed() -> void:
    potential_inspect_requested.emit()


func _on_condition_pressed() -> void:
    condition_inspect_requested.emit()


func _on_xray_pressed() -> void:
    xray_inspect_requested.emit()


func _on_cancel_pressed() -> void:
    cancelled.emit()


func _is_potential_action_disabled() -> bool:
    return RunManager.run_record.stamina < POTENTIAL_COST or RunManager.run_record.actions_remaining <= 0


func _is_condition_action_disabled() -> bool:
    return RunManager.run_record.stamina < CONDITION_COST or RunManager.run_record.actions_remaining <= 0


func _is_xray_action_disabled() -> bool:
    return RunManager.run_record.stamina < XRAY_COST or RunManager.run_record.actions_remaining <= 0
