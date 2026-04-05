# location_browse_testbed.gd
# Location browse testbed — injects a fake run state and launches the
# location browse scene directly, bypassing Blocks 01–02.
#
# Drag a LocationData .tres into the location_data export in the Inspector.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LocationBrowseScene := preload("res://game/location_browse/location_browse_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# LocationData resource to browse. Drag a .tres here in the Inspector.
@export var location_data: LocationData

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_location_browse_scene()

# ══ Setup helpers ══════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    GameManager.run_record = RunRecord.create(location_data)


func _launch_location_browse_scene() -> void:
    var scene: Control = LocationBrowseScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
