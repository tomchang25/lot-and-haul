# warehouse_entry.gd
# Run entry point — Warehouse Exterior.
# Clears all previous run state, generates fresh item_entries and lot_data,
# plays the door-open animation, then advances automatically to Block 02.
# No player input required.
extends Control

# ── Node references ───────────────────────────────────────────────────────────
const WarehouseLotData = preload("res://data/locations/warehouse_lotdata.tres")
const ClosedTexture := preload("res://assets/warehouse_closed.png")
const OpenTexture := preload("res://assets/warehouse_open.png")

@export var lot_data: LotData = WarehouseLotData

@onready var _texture_rect: TextureRect = $TextureRect

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _init_run()
    _play_door_animation()


# ══ Run initialisation ════════════════════════════════════════════════════════
func _init_run() -> void:
    var lot_entry := LotEntry.create(lot_data)
    GameManager.run_record = RunRecord.create(lot_entry)
    GameManager.run_record.actions_remaining = GameManager.run_record.lot_entry.lot_data.action_quota

# ══ Door animation ════════════════════════════════════════════════════════════


func _play_door_animation() -> void:
    _texture_rect.texture = ClosedTexture
    var tween := create_tween()
    tween.tween_interval(0.2)
    tween.tween_property(_texture_rect, "modulate:a", 0.0, 0.4)
    tween.tween_callback(func() -> void: _texture_rect.texture = OpenTexture)
    tween.tween_property(_texture_rect, "modulate:a", 1.0, 0.4)
    tween.tween_interval(0.2)
    tween.tween_callback(GameManager.go_to_inspection)
