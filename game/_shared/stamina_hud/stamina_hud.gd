class_name StaminaHUD
extends HBoxContainer

@onready var _value_label: Label = $ValueLabel


func update_stamina(current: int, maximum: int) -> void:
    _value_label.text = "%d / %d" % [current, maximum]
