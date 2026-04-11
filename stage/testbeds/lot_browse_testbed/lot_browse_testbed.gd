# lot_browse_testbed.gd
# Lot browse testbed — injects a fake run state and launches the
# lot browse scene directly, bypassing Blocks 01–02.
#
# Drag a LocationData .tres into the location_data export in the Inspector.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LotBrowseScene := preload("res://game/lot_browse/lot_browse_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# LocationData resource to browse. Drag a .tres here in the Inspector.
@export var location_data: LocationData

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_lot_browse_scene()

# ══ Setup helpers ══════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    RunManager.run_record = RunRecord.create(location_data, SaveManager.load_active_car())


func _launch_lot_browse_scene() -> void:
    var scene: Control = LotBrowseScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
