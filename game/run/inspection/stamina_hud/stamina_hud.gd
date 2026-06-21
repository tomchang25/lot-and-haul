class_name StaminaHUD
extends VBoxContainer

@onready var _ap_label: Label = $APLabel


func update_ap(current: int, maximum: int) -> void:
    _ap_label.text = TranslationServer.translate("UI_AP_HUD") % [current, maximum]
