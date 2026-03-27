@tool
class_name SpatialAudioEvent
extends AudioEvent

@export_group("Limiter")
@export var limiter_key: StringName = &""
@export var max_per_window: int = 2
@export var window_sec: float = 0.05


func _init() -> void:
    bus_id = AudioBus.Id.SOUND
    use_random_pitch = true
    pitch_random_min = 0.95
    pitch_random_max = 1.05
