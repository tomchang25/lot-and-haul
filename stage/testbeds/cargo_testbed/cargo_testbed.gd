# cargo_testbed.gd
# Block 05 testbed — simulates a won auction and launches cargo_scene (2-D grid)
# directly, bypassing Blocks 01–04.
#
# Run this scene to test cargo loading in isolation.
# Edit the @export fields in the Inspector to configure fake state.
# Legacy list-based scene is still available as cargo_scene_legacy.tscn.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const CargoScene := preload("res://game/cargo/cargo_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# Simulated amount paid at auction (shown in Block 06 settlement).
@export var paid_price: int = 1800

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_cargo_scene()

# ══ Setup helpers ══════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    const WAREHOUSE_LOTDATA = preload("uid://l8xrnjwietdt")
    const WAREHOUSE_LOCATION = preload("res://data/tres/locations/warehouse_location.tres")

    var lot := LotEntry.create(WAREHOUSE_LOTDATA)
    RunManager.run_record = RunRecord.create(WAREHOUSE_LOCATION, SaveManager.active_car)
    RunManager.run_record.set_lot(lot)

    var entries: Array[ItemEntry] = RunManager.run_record.lot_entry.item_entries

    for entry: ItemEntry in entries:
        entry.inspection_level = 4.0
        entry.layer_index = 1

    RunManager.run_record.paid_price = paid_price
    RunManager.run_record.won_items = entries.duplicate()
    RunManager.run_record.cargo_items.clear()


func _launch_cargo_scene() -> void:
    var scene: Control = CargoScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
