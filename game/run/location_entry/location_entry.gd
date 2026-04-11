# location_entry.gd
# Run entry point — Location Entry.
# Assumes RunManager.run_record has already been built by the Location Select
# screen. Plays the placeholder arrival fade, then advances to lot browse.
# No player input required.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _texture_rect: TextureRect = $TextureRect

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    assert(RunManager.run_record != null, "LocationEntry: RunManager.run_record is null — Location Select must build it before entering.")
    assert(RunManager.run_record.location_data != null, "LocationEntry: RunManager.run_record.location_data is null — Location Select must assign a LocationData before entering.")
    _play_door_animation()

# ══ Door animation ════════════════════════════════════════════════════════════


# TODO: per-location arrival visuals come from a later block. For now this is
# a placeholder fade that still fires the lot-browse callback so downstream
# scenes are reachable.
func _play_door_animation() -> void:
    var tween := create_tween()
    tween.tween_interval(0.2)
    tween.tween_property(_texture_rect, "modulate:a", 0.0, 0.4)
    tween.tween_property(_texture_rect, "modulate:a", 1.0, 0.4)
    tween.tween_interval(0.2)
    tween.tween_callback(GameManager.go_to_lot_browse)
