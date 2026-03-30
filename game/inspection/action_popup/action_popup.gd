class_name ActionPopup
extends PanelContainer

signal browse_requested
signal examine_requested
signal cancelled

@onready var _browse_btn: Button = $VBox/BrowseButton
@onready var _examine_btn: Button = $VBox/ExamineButton


func _ready() -> void:
    $VBox/BrowseButton.pressed.connect(_on_browse_pressed)
    $VBox/ExamineButton.pressed.connect(_on_examine_pressed)
    $VBox/CancelButton.pressed.connect(_on_cancel_pressed)


# Update button enabled/greyed state based on current item level and stamina.
func refresh(item_level: int, stamina: int) -> void:
    var browse_ok := InspectionRules.can_browse(item_level, stamina)
    _browse_btn.disabled = not browse_ok
    _browse_btn.modulate.a = 1.0 if browse_ok else 0.45

    var examine_cost := InspectionRules.examine_cost(item_level)
    var examine_ok := InspectionRules.can_examine(item_level, stamina)
    _examine_btn.disabled = not examine_ok
    _examine_btn.modulate.a = 1.0 if examine_ok else 0.45
    _examine_btn.text = "Examine (%d SP)" % examine_cost


func _on_browse_pressed() -> void:
    browse_requested.emit()


func _on_examine_pressed() -> void:
    examine_requested.emit()


func _on_cancel_pressed() -> void:
    cancelled.emit()
