# warehouse_entry.gd
# Run entry point — Warehouse Exterior.
# Clears all previous run state, generates fresh item_entries and lot_data,
# plays the door-open animation, then advances automatically to Block 02.
# No player input required.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

# Fixed lot for the vertical slice. Replace with dynamic selection post-MVP.
const ITEM_PATHS: Array[String] = [
    "res://data/items/brass_lamp.tres",
    "res://data/items/pocket_watch.tres",
    "res://data/items/oil_painting.tres",
    "res://data/items/wooden_clock.tres",
]

# ── Node references ───────────────────────────────────────────────────────────

const ClosedTexture := preload("res://assets/warehouse_closed.png")
const OpenTexture := preload("res://assets/warehouse_open.png")

@onready var _texture_rect: TextureRect = $TextureRect

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _init_run()
    _play_door_animation()

# ══ Run initialisation ════════════════════════════════════════════════════════


func _init_run() -> void:
    # Clear all previous run state.
    GameManager.item_entries.clear()
    GameManager.lot_data = null
    GameManager.lot_result = { }
    GameManager.cargo_items.clear()
    GameManager.run_result = { }

    # Generate one ItemEntry per item preset.
    for path: String in ITEM_PATHS:
        var item := load(path) as ItemData
        if item == null:
            push_error("warehouse_entry: failed to load item at %s" % path)
            continue

        var entry := ItemEntry.create(item, 0.2)
        GameManager.item_entries.append(entry)

    # Generate lot_data.
    var ld := LotData.new()
    ld.aggressive_factor = 1.0 # MVP: fixed
    GameManager.lot_data = ld

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
