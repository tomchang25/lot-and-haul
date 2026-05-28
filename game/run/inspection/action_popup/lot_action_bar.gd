class_name LotActionBar
extends PanelContainer

signal inspect_requested

const INSPECT_COST := 1

@onready var _inspect_button: Button = $HBoxContainer/InspectButton


func _ready() -> void:
    _inspect_button.pressed.connect(_on_inspect_pressed)


func refresh_lot(selected_entry: ItemEntry) -> void:
    var stamina: int = RunManager.run_record.stamina
    var actions: int = RunManager.run_record.actions_remaining
    var actions_ok: bool = actions > 0

    var can_inspect: bool = (
        selected_entry != null
        and selected_entry.is_veiled()
    )
    can_inspect = (
        can_inspect
        and stamina >= INSPECT_COST
        and actions_ok
    )

    _inspect_button.disabled = not can_inspect
    _inspect_button.text = "Inspect (%d SP)" % INSPECT_COST

    reset_size()


func _on_inspect_pressed() -> void:
    inspect_requested.emit()
