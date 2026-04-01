class_name ActionPopup
extends PanelContainer

signal advance_requested
signal cancelled

@onready var _advance_btn: Button = $VBox/BrowseButton
@onready var _examine_btn: Button = $VBox/ExamineButton


func _ready() -> void:
    $VBox/BrowseButton.pressed.connect(_on_advance_pressed)
    $VBox/CancelButton.pressed.connect(_on_cancel_pressed)
    _examine_btn.hide()


# Update button state based on the entry's current unlock action and available stamina.
func refresh(entry: ItemEntry, stamina: int) -> void:
    var action := entry.current_unlock_action()
    var can_do := InspectionRules.can_advance(entry, stamina)

    if action == null:
        _advance_btn.text = "Inspect"
        _advance_btn.disabled = true
        _advance_btn.modulate.a = 0.45
        return

    _advance_btn.text = "Inspect (%d SP)" % action.stamina_cost
    _advance_btn.disabled = not can_do
    _advance_btn.modulate.a = 1.0 if can_do else 0.45


func _on_advance_pressed() -> void:
    advance_requested.emit()


func _on_cancel_pressed() -> void:
    cancelled.emit()
