class_name ActionPopup
extends PanelContainer

signal browse_requested
signal examine_requested
signal cancelled

const _BROWSE_COST := 1
const _EXAMINE_COST_FROM_0 := 3
const _EXAMINE_COST_FROM_1 := 2

@onready var _browse_btn: Button = $VBox/BrowseButton
@onready var _examine_btn: Button = $VBox/ExamineButton


func _ready() -> void:
	$VBox/BrowseButton.pressed.connect(_on_browse_pressed)
	$VBox/ExamineButton.pressed.connect(_on_examine_pressed)
	$VBox/CancelButton.pressed.connect(_on_cancel_pressed)


# Update button enabled/greyed state based on current item level and stamina.
func refresh(item_level: int, stamina: int) -> void:
	# Browse: disabled when item is already level 1+ or player can't afford
	var browse_ok := item_level < 1 and stamina >= _BROWSE_COST
	_browse_btn.disabled = not browse_ok
	_browse_btn.modulate.a = 1.0 if browse_ok else 0.45

	# Examine: upgrade from level 1 costs 2 SP; from level 0 costs 3 SP
	var examine_cost := _EXAMINE_COST_FROM_1 if item_level == 1 else _EXAMINE_COST_FROM_0
	var examine_ok := item_level < 2 and stamina >= examine_cost
	_examine_btn.disabled = not examine_ok
	_examine_btn.modulate.a = 1.0 if examine_ok else 0.45
	_examine_btn.text = "Examine (%d SP)" % examine_cost


func _on_browse_pressed() -> void:
	browse_requested.emit()


func _on_examine_pressed() -> void:
	examine_requested.emit()


func _on_cancel_pressed() -> void:
	cancelled.emit()
