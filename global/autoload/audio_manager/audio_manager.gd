extends Node

# Simple, robust audio singleton:
# - pooled SFX players (2D + non-positional)
# - a music player
# - limiter to prevent SFX spam per-key

@export_group("Buses")
@export var bus_map := {
    AudioBus.Id.NONE: &"Master",
    AudioBus.Id.SOUND: &"SFX",
    AudioBus.Id.MUSIC: &"Music",
    AudioBus.Id.UI: &"UI",
}

@export_group("Pool")
@export var sfx_pool_2d_size: int = 24
@export var sfx_pool_ui_size: int = 8

var _music_player: AudioStreamPlayer
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _ui_pool: Array[AudioStreamPlayer] = []

# key -> Array[tick_msec]
var _rate_history: Dictionary = {}


func _ready() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = get_bus_name(AudioBus.Id.MUSIC)
    add_child(_music_player)

    # 2D SFX pool
    for i in range(max(1, sfx_pool_2d_size)):
        var p := AudioStreamPlayer2D.new()
        p.name = "Sfx2D_%02d" % i
        p.bus = get_bus_name(AudioBus.Id.SOUND)
        p.finished.connect(func(): p.stream = null)
        add_child(p)
        _sfx_2d_pool.append(p)

    # UI / non-positional SFX pool
    for i in range(max(1, sfx_pool_ui_size)):
        var u := AudioStreamPlayer.new()
        u.name = "UiSfx_%02d" % i
        u.bus = get_bus_name(AudioBus.Id.UI)
        u.finished.connect(func(): u.stream = null)
        add_child(u)
        _ui_pool.append(u)


# -------------------------
# Bus helpers
# -------------------------


func get_bus_name(bus_id: int) -> StringName:
    return bus_map.get(bus_id, &"Master")


func _resolve_bus_name(event: AudioEvent, fallback_bus_id: int) -> StringName:
    if event.bus_id == AudioBus.Id.NONE:
        push_error("AudioEvent: bus_id is NONE")

    if event.bus_id != AudioBus.Id.OTHER:
        return get_bus_name(event.bus_id)

    if event.bus_override != &"":
        return event.bus_override

    return get_bus_name(fallback_bus_id)


# -------------------------
# Public API
# -------------------------


func play_music(stream: AudioStream, volume_db: float = 0.0, from_sec: float = 0.0, bus_override: StringName = &"") -> void:
    if stream == null:
        return
    _music_player.bus = bus_override if bus_override != &"" else get_bus_name(AudioBus.Id.MUSIC)
    _music_player.stop()
    _music_player.stream = stream
    _music_player.volume_db = volume_db
    _music_player.play(from_sec)


func stop_music() -> void:
    _music_player.stop()


func play_ui(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, bus_override: StringName = &"") -> void:
    if stream == null:
        return
    var p := _get_free_ui_player()
    if p == null:
        return
    p.stop()
    p.stream = stream
    p.volume_db = volume_db
    p.pitch_scale = pitch
    p.bus = bus_override if bus_override != &"" else get_bus_name(AudioBus.Id.UI)
    p.play()


func play_sfx_2d(stream: AudioStream, world_pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0, bus_override: StringName = &"") -> void:
    if stream == null:
        return
    var p := _get_free_sfx_2d_player()
    if p == null:
        return
    p.stop()
    p.stream = stream
    p.global_position = world_pos
    p.volume_db = volume_db
    p.pitch_scale = pitch
    p.bus = bus_override if bus_override != &"" else get_bus_name(AudioBus.Id.SOUND)
    p.play()


func play_sfx_limited(
    stream: AudioStream,
    key: StringName,
    world_pos: Vector2,
    max_per_window: int = 4,
    window_sec: float = 0.05,
    volume_db: float = 0.0,
    pitch: float = 1.0,
    bus_override: StringName = &""
) -> void:
    if stream == null:
        return
    if _is_rate_limited(key, max_per_window, window_sec):
        return
    play_sfx_2d(stream, world_pos, volume_db, pitch, bus_override)


# -------------------------
# Unified API: play_event
# -------------------------


func play_event(event: AudioEvent, world_pos: Vector2 = Vector2.ZERO) -> void:
    if event == null:
        return

    var stream := event.pick_stream()
    if stream == null:
        return

    var pitch := event.resolve_pitch()

    # Music
    if event is MusicAudioEvent:
        var e := event as MusicAudioEvent
        var bus_name := _resolve_bus_name(event, AudioBus.Id.MUSIC)

        if not e.restart_if_same and _music_player.playing and _music_player.stream == stream:
            return

        play_music(stream, e.volume_db, e.from_sec, bus_name)
        return

    # UI
    if event is UiAudioEvent:
        var e := event as UiAudioEvent
        var bus_name := _resolve_bus_name(event, AudioBus.Id.UI)

        if e.limiter_key != &"" and _is_rate_limited(e.limiter_key, e.max_per_window, e.window_sec):
            return

        play_ui(stream, e.volume_db, pitch, bus_name)
        return

    # Spatial
    if event is SpatialAudioEvent:
        var e := event as SpatialAudioEvent
        var bus_name := _resolve_bus_name(event, AudioBus.Id.SOUND)

        if e.limiter_key != &"":
            play_sfx_limited(stream, e.limiter_key, world_pos, e.max_per_window, e.window_sec, e.volume_db, pitch, bus_name)
        else:
            play_sfx_2d(stream, world_pos, e.volume_db, pitch, bus_name)
        return

    # Fallback
    var fallback_bus := _resolve_bus_name(event, AudioBus.Id.SOUND)
    play_sfx_2d(stream, world_pos, event.volume_db, pitch, fallback_bus)


# -------------------------
# Internals
# -------------------------


func _get_free_sfx_2d_player() -> AudioStreamPlayer2D:
    for p in _sfx_2d_pool:
        if not p.playing:
            return p
    # If all busy, reuse the oldest/first (cheap fallback)
    return _sfx_2d_pool[0] if not _sfx_2d_pool.is_empty() else null


func _get_free_ui_player() -> AudioStreamPlayer:
    for p in _ui_pool:
        if not p.playing:
            return p
    return _ui_pool[0] if not _ui_pool.is_empty() else null


func _is_rate_limited(key: StringName, max_per_window: int, window_sec: float) -> bool:
    if key == &"":
        # No key => no limiting
        return false

    var now := Time.get_ticks_msec()
    var window_msec := int(max(0.0, window_sec) * 1000.0)

    var arr: Array = _rate_history.get(key, [])
    # prune old
    var kept: Array = []
    for t in arr:
        if now - int(t) <= window_msec:
            kept.append(t)
    arr = kept

    if arr.size() >= max(0, max_per_window):
        _rate_history[key] = arr
        return true

    arr.append(now)
    _rate_history[key] = arr
    return false
