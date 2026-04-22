class_name LotActionBar
extends PanelContainer

signal inspect_requested
signal peek_requested
signal appraise_requested

const INSPECT_COST := 1
const PEEK_COST := 2
const APPRAISE_COST := 2

@onready var _inspect_button: Button = $HBoxContainer/InspectButton
@onready var _peek_button: Button = $HBoxContainer/PeekButton
@onready var _appraise_button: Button = $HBoxContainer/AppraiseButton


func _ready() -> void:
    _inspect_button.pressed.connect(_on_inspect_pressed)
    _peek_button.pressed.connect(_on_peek_pressed)
    _appraise_button.pressed.connect(_on_appraise_pressed)


func refresh_lot(selected_entry: ItemEntry) -> void:
    var stamina: int = RunManager.run_record.stamina
    var actions: int = RunManager.run_record.actions_remaining
    var actions_ok: bool = actions > 0

    var can_inspect: bool = (
        selected_entry != null
        and not selected_entry.is_veiled()
        and selected_entry.is_condition_inspectable()
        and stamina >= INSPECT_COST
        and actions_ok
    )
    var has_veiled: bool = false
    for entry: ItemEntry in RunManager.run_record.lot_items:
        if entry.is_veiled():
            has_veiled = true
            break

    var can_peek: bool = (
        has_veiled
        and stamina >= PEEK_COST
        and actions_ok
    )

    var can_appraise: bool = (
        selected_entry != null
        and not selected_entry.is_veiled()
        and selected_entry.intuition_level < selected_entry.max_intuition_level
        and stamina >= APPRAISE_COST
        and actions_ok
    )

    _inspect_button.disabled = not can_inspect
    _inspect_button.text = "Inspect (%d SP)" % INSPECT_COST

    _peek_button.visible = true
    _peek_button.disabled = not can_peek
    _peek_button.text = "Peek (%d SP)" % PEEK_COST

    _appraise_button.disabled = not can_appraise
    _appraise_button.text = "Appraise (%d SP)" % APPRAISE_COST

    reset_size()


func _on_inspect_pressed() -> void:
    inspect_requested.emit()


func _on_peek_pressed() -> void:
    peek_requested.emit()


func _on_appraise_pressed() -> void:
    appraise_requested.emit()
