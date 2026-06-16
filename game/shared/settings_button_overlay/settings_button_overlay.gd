# settings_button_overlay.gd
# Static scene overlay that opens the project settings menu from gameplay screens.
extends CanvasLayer

@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
    _settings_button.pressed.connect(_on_settings_pressed)


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()
