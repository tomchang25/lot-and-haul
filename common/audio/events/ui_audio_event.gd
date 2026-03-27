@tool
class_name UiAudioEvent
extends AudioEvent

@export_group("Limiter")
@export var limiter_key: StringName = &""
@export var max_per_window: int = 8
@export var window_sec: float = 0.05


func _init() -> void:
    bus_id = AudioBus.Id.UI
    use_random_pitch = true
    pitch_random_min = 0.98
    pitch_random_max = 1.02
