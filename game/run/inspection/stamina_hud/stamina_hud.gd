class_name StaminaHUD
extends VBoxContainer

@onready var _stamina_label: Label = $StaminaLabel
@onready var _action_label: Label = $ActionLabel


func update_stamina(current: int, maximum: int) -> void:
    _stamina_label.text = "SP  %d / %d" % [current, maximum]


func update_actions(remaining: int) -> void:
    _action_label.text = "Actions  %d" % remaining
