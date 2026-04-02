class_name ActionPopup
extends PanelContainer

signal advance_requested
signal cancelled

@onready var _advance_button: Button = $VBox/AdvanceButton
@onready var _cancel_button: Button = $VBox/CancelButton


func _ready() -> void:
    _advance_button.pressed.connect(_on_advance_pressed)
    _cancel_button.pressed.connect(_on_cancel_pressed)


# Update button state based on the entry's current unlock action and available stamina.
func refresh(entry: ItemEntry, stamina: int) -> void:
    var action := entry.current_unlock_action()
    var can_do := KnowledgeManager.can_advance(entry, stamina)

    if action == null:
        _advance_button.text = "Done"
        _advance_button.disabled = true
        _advance_button.modulate.a = 0.45
        return

    _advance_button.disabled = not can_do
    if can_do:
        _advance_button.text = "Inspect (%d SP)" % action.stamina_cost
    else:
        _advance_button.text = "Inspect (Requirments not met)"
    _advance_button.modulate.a = 1.0 if can_do else 0.45


func _on_advance_pressed() -> void:
    advance_requested.emit()


func _on_cancel_pressed() -> void:
    cancelled.emit()
