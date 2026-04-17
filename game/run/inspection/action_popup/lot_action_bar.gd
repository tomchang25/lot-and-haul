class_name LotActionBar
extends PanelContainer

signal inspect_requested
signal peek_requested

const INSPECT_COST := 2
const PEEK_COST := 3

@onready var _inspect_button: Button = $HBoxContainer/InspectButton
@onready var _peek_button: Button = $HBoxContainer/PeekButton


func _ready() -> void:
    _inspect_button.pressed.connect(_on_inspect_pressed)
    _peek_button.pressed.connect(_on_peek_pressed)


func refresh_lot(has_inspectable: bool, has_veiled: bool) -> void:
    var stamina: int = RunManager.run_record.stamina
    var actions: int = RunManager.run_record.actions_remaining
    var actions_ok: bool = actions > 0

    _inspect_button.disabled = (
        not has_inspectable
        or stamina < INSPECT_COST
        or not actions_ok
    )
    _inspect_button.text = "Inspect (%d SP)" % INSPECT_COST

    _peek_button.visible = has_veiled
    _peek_button.disabled = (
        not has_veiled
        or stamina < PEEK_COST
        or not actions_ok
    )
    _peek_button.text = "Try to Peek (%d SP)" % PEEK_COST

    reset_size()


func _on_inspect_pressed() -> void:
    inspect_requested.emit()


func _on_peek_pressed() -> void:
    peek_requested.emit()
