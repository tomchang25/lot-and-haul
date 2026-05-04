class_name LotActionBar
extends PanelContainer

signal inspect_requested
signal appraise_requested

const INSPECT_COST := 1
const APPRAISE_COST := 2

@onready var _inspect_button: Button = $HBoxContainer/InspectButton
@onready var _appraise_button: Button = $HBoxContainer/AppraiseButton


func _ready() -> void:
    _inspect_button.pressed.connect(_on_inspect_pressed)
    _appraise_button.pressed.connect(_on_appraise_pressed)


func refresh_lot(selected_entry) -> void:
    var stamina: int = RunManager.run_record.stamina
    var actions: int = RunManager.run_record.actions_remaining
    var actions_ok: bool = actions > 0
    var entry := selected_entry as LotObjectEntry

    var can_inspect: bool = (
        entry != null
        and entry.can_inspect()
    )
    can_inspect = (
        can_inspect
        and stamina >= INSPECT_COST
        and actions_ok
    )

    var can_appraise: bool = (
        entry != null
        and entry.can_appraise()
        and stamina >= APPRAISE_COST
        and actions_ok
    )

    _inspect_button.disabled = not can_inspect
    _inspect_button.text = "Inspect (%d SP)" % INSPECT_COST

    _appraise_button.disabled = not can_appraise
    _appraise_button.text = "Appraise (%d SP)" % APPRAISE_COST

    reset_size()


func _on_inspect_pressed() -> void:
    inspect_requested.emit()


func _on_appraise_pressed() -> void:
    appraise_requested.emit()
