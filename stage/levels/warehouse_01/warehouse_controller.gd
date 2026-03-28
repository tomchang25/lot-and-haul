# warehouse_controller.gd
# Manages the warehouse background state (door open / closed).
# Swap the Background texture to switch between closed and open states.
# Item spawn points are defined as Marker2D children of ItemSpawnPoints.
extends Node

@onready var background: Sprite2D = $"../Background"

@export var texture_closed: Texture2D
@export var texture_open: Texture2D


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_O:
        open_door()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
        close_door()


# Call this to reveal the interior (inspection phase begins)
func open_door() -> void:
    var tween := create_tween()
    tween.tween_method(_set_modulate_a, 1.0, 0.0, 0.15)
    tween.tween_callback(
        func():
            background.texture = texture_open
    )
    tween.tween_method(_set_modulate_a, 0.0, 1.0, 0.15)


# Call this to show the closed door (auction phase / before reveal)
func close_door() -> void:
    background.texture = texture_closed


func _set_modulate_a(a: float) -> void:
    background.modulate.a = a


# Returns all spawn point positions for item placement
func get_spawn_positions() -> Array[Vector2]:
    var points: Array[Vector2] = []
    for child in $"../ItemSpawnPoints".get_children():
        if child is Marker2D:
            points.append(child.global_position)
    return points
