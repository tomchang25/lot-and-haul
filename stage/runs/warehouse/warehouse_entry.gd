# warehouse_entry.gd
# Run entry point — Warehouse Exterior.
# Clears all previous run state, creates a fresh RunRecord from LocationData,
# plays the door-open animation, then advances to location browse.
# No player input required.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

const ClosedTexture := preload("res://assets/warehouse_closed.png")
const OpenTexture := preload("res://assets/warehouse_open.png")

@export var location_data: LocationData

@onready var _texture_rect: TextureRect = $TextureRect

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _init_run()
    _play_door_animation()

# ══ Run initialisation ════════════════════════════════════════════════════════


func _init_run() -> void:
    RunManager.run_record = RunRecord.create(location_data, SaveManager.load_active_car())

# ══ Door animation ════════════════════════════════════════════════════════════


func _play_door_animation() -> void:
    _texture_rect.texture = ClosedTexture
    var tween := create_tween()
    tween.tween_interval(0.2)
    tween.tween_property(_texture_rect, "modulate:a", 0.0, 0.4)
    tween.tween_callback(func() -> void: _texture_rect.texture = OpenTexture)
    tween.tween_property(_texture_rect, "modulate:a", 1.0, 0.4)
    tween.tween_interval(0.2)
    tween.tween_callback(GameManager.go_to_lot_browse)
