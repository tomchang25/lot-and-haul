@tool
class_name MusicAudioEvent
extends AudioEvent

@export_group("Music")
@export var from_sec: float = 0.0
@export var restart_if_same: bool = false


func _init() -> void:
    bus_id = AudioBus.Id.MUSIC
    use_random_pitch = false
    pitch_scale = 1.0
