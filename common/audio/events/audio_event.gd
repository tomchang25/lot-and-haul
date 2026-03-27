class_name AudioEvent
extends Resource

@export_group("Playback")
@export var volume_db: float = 0.0

@export_group("Bus")
@export var bus_id: AudioBus.Id = AudioBus.Id.NONE
@export var bus_override: StringName = &""

@export_group("Streams")
@export var streams: Array[AudioStream] = []
@export var avoid_repeat := true

@export_group("Pitch")
@export var use_random_pitch := false
@export_range(0.01, 4.0, 0.01) var pitch_scale: float = 1.0
@export_range(0.01, 4.0, 0.01) var pitch_random_min: float = 0.95
@export_range(0.01, 4.0, 0.01) var pitch_random_max: float = 1.05

var _last_index := -1


func pick_stream() -> AudioStream:
    if streams.is_empty():
        return null

    if streams.size() == 1:
        _last_index = 0
        return streams[0]

    var index := randi() % streams.size()

    if avoid_repeat and index == _last_index:
        index = (index + 1) % streams.size()

    _last_index = index
    return streams[index]


func resolve_pitch() -> float:
    if use_random_pitch:
        var min_pitch: float = min(pitch_random_min, pitch_random_max)
        var max_pitch: float = max(pitch_random_min, pitch_random_max)
        return randf_range(min_pitch, max_pitch)

    return pitch_scale
