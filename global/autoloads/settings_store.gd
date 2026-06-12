# settings_store.gd
# Project-wide persistent settings (audio, display, gameplay). Self-persists to user://settings.json. Not a gameplay Store.
extends Node

signal debug_mode_changed(value: bool)

const SETTINGS_PATH := "user://settings.json"
const SettingsOverlayScene := preload("res://game/shared/settings_overlay/settings_overlay.tscn")

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var debug_mode: bool = false:
    set(value):
        if debug_mode == value:
            return
        debug_mode = value
        debug_mode_changed.emit(value)

var _overlay_instance: CanvasLayer = null


func _ready() -> void:
    load_settings()
    apply_audio()
    apply_display()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_settings"):
        toggle_overlay()
        get_viewport().set_input_as_handled()


func save_settings() -> void:
    var data := {
        "master_volume": master_volume,
        "sfx_volume": sfx_volume,
        "music_volume": music_volume,
        "fullscreen": fullscreen,
        "debug_mode": debug_mode,
    }
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SettingsStore: cannot write %s" % SETTINGS_PATH) # push-error: boot
        return
    file.store_string(JSON.stringify(data))


func load_settings() -> void:
    if not FileAccess.file_exists(SETTINGS_PATH):
        return
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if file == null:
        push_error("SettingsStore: cannot read %s" % SETTINGS_PATH) # push-error: boot
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed == null or not parsed is Dictionary:
        push_error("SettingsStore: invalid settings data") # push-error: boot
        return
    var d: Dictionary = parsed
    master_volume = d.get("master_volume", 1.0)
    sfx_volume = d.get("sfx_volume", 1.0)
    music_volume = d.get("music_volume", 1.0)
    fullscreen = d.get("fullscreen", false)
    debug_mode = d.get("debug_mode", false)


func apply_audio() -> void:
    _set_bus_volume("Master", master_volume)
    _set_bus_volume("SFX", sfx_volume)
    _set_bus_volume("Music", music_volume)


func apply_display() -> void:
    if fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_overlay() -> void:
    if _overlay_instance != null:
        _close_overlay()
    else:
        _open_overlay()


func _open_overlay() -> void:
    if _overlay_instance != null:
        return
    _overlay_instance = SettingsOverlayScene.instantiate()
    _overlay_instance.closed.connect(_close_overlay)
    get_tree().root.add_child(_overlay_instance)
    get_tree().paused = true


func _close_overlay() -> void:
    if _overlay_instance == null:
        return
    _overlay_instance.queue_free()
    _overlay_instance = null
    get_tree().paused = false


func _set_bus_volume(bus_name: String, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1:
        push_error("SettingsStore: bus '%s' not found" % bus_name) # push-error: boot
        return
    AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
    AudioServer.set_bus_mute(idx, linear <= 0.0)
