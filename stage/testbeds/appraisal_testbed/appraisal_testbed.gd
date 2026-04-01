# appraisal_testbed.gd
# Block 06 testbed — simulates a completed cargo selection and launches the
# appraisal scene directly, bypassing Blocks 01–05.
#
# Run this scene to test Home Appraisal in isolation.
# Edit the @export fields in the Inspector to configure fake state.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const AppraisalScene := preload("res://game/appraisal/appraisal_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# Items the player loaded onto the truck. Drag .tres files here.
# These become GameManager.cargo_items — the items whose true_value is revealed.
@export var cargo_items: Array[ItemData] = []

# Simulated amount paid at auction (used in the profit / loss calculation).
@export var paid_price: int = 1800

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_appraisal_scene()

# ══ Setup ═════════════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    const WAREHOUSE_LOTDATA = preload("uid://l8xrnjwietdt")

    var lot := LotEntry.create(WAREHOUSE_LOTDATA)
    GameManager.run_record = RunRecord.create(lot)

    # Populate cargo_items so appraisal_scene can iterate and reveal values.
    GameManager.run_record.cargo_items.clear()
    for item: ItemData in cargo_items:
        var entry := ItemEntry.create(item)
        GameManager.run_record.cargo_items.append(entry)

    # Simulate the lot result written by Block 04.
    GameManager.run_record.paid_price = paid_price


func _launch_appraisal_scene() -> void:
    var scene: Control = AppraisalScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
