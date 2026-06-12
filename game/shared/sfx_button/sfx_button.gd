# sfx_button.gd
# Button subclass that plays default press/hover UI audio events; per-button override or mute via exports.
class_name SfxButton
extends Button

const DEFAULT_PRESS: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")
const DEFAULT_HOVER: UiAudioEvent = preload("res://data/tres/audio_events/button_hover.tres")

@export var press_event: UiAudioEvent = DEFAULT_PRESS
@export var hover_event: UiAudioEvent = DEFAULT_HOVER


func _ready() -> void:
    button_down.connect(_on_press)
    mouse_entered.connect(_on_hover)
    focus_entered.connect(_on_hover)


func _on_press() -> void:
    if disabled or press_event == null:
        return
    AudioManager.play_event(press_event)


func _on_hover() -> void:
    if disabled or hover_event == null:
        return
    AudioManager.play_event(hover_event)
