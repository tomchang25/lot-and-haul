# appraisal_testbed.gd
# Block 06 testbed — simulates a completed cargo selection and launches the
# appraisal scene directly, bypassing Blocks 01–05.
#
# Run this scene to test Home Appraisal in isolation.
# Edit the @export arrays in the Inspector to change which items are carried
# into appraisal and what price was paid at auction.
extends Control

const AppraisalScene := preload("res://stage/levels/appraisal/appraisal_scene.tscn")

# ── Testbed configuration (edit in Inspector) ──────────────────────────────────

# Items the player loaded onto the truck. Drag .tres files here.
# These become GameManager.cargo_items — the items whose true_value is revealed.
@export var cargo_items: Array[ItemData] = []

# Simulated amount paid at auction (used in the profit / loss calculation).
@export var paid_price: int = 1800

# ── Lifecycle ─────────────────────────────────────────────────────────────────


func _ready() -> void:
    _inject_fake_state()
    _launch_appraisal_scene()

# ── Helpers ───────────────────────────────────────────────────────────────────


func _inject_fake_state() -> void:
    # Populate cargo_items so appraisal_scene can iterate and reveal values.
    GameManager.cargo_items.clear()
    for item: ItemData in cargo_items:
        GameManager.cargo_items.append(item)

    # Simulate the lot result written by Block 04.
    GameManager.lot_result = {
        &"paid_price": paid_price,
    }

    # Clear any leftover run result from a previous session.
    GameManager.run_result = {}


func _launch_appraisal_scene() -> void:
    var scene: Control = AppraisalScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
