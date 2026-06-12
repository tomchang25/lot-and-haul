# click_binder.gd
# Autoload: walks the active scene on every transition and binds button clicks
# to a shared UiAudioEvent. Buttons with meta sfx_click_ignore = true are skipped.
extends Node

const CLICK_EVENT: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")


func _ready() -> void:
    SceneRouter.scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    _walk(scene)


func _walk(node: Node) -> void:
    if node is Button:
        var btn: Button = node as Button
        if not btn.has_meta("sfx_click_ignore") or not btn.get_meta("sfx_click_ignore"):
            if not btn.pressed.is_connected(_on_click):
                btn.pressed.connect(_on_click)
    for child: Node in node.get_children():
        _walk(child)


func _on_click() -> void:
    AudioManager.play_event(CLICK_EVENT)
