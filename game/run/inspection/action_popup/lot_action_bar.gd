class_name LotActionBar
extends PanelContainer

signal inspect_requested
signal peek_requested

const INSPECT_COST := 1
const PEEK_COST := 3

@onready var _inspect_button: Button = $HBoxContainer/InspectButton
@onready var _peek_button: Button = $HBoxContainer/PeekButton


func _ready() -> void:
    _inspect_button.pressed.connect(_on_inspect_pressed)
    _peek_button.pressed.connect(_on_peek_pressed)


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
    var can_peek: bool = (
        selected_entry != null
        and selected_entry.is_veiled()
        and stamina >= PEEK_COST
        and actions_ok
    )

    _inspect_button.disabled = not can_inspect
    _inspect_button.text = "Inspect (%d SP)" % INSPECT_COST

    _peek_button.visible = selected_entry != null and selected_entry.is_veiled()
    _peek_button.disabled = not can_peek
    _peek_button.text = "Try to Peek (%d SP)" % PEEK_COST

    reset_size()


func _on_inspect_pressed() -> void:
    inspect_requested.emit()


func _on_peek_pressed() -> void:
    peek_requested.emit()
