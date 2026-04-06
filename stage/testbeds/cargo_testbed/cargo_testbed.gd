# cargo_testbed.gd
# Block 05 testbed — simulates a won auction and launches the cargo scene
# directly, bypassing Blocks 01–04.
#
# Run this scene to test cargo loading in isolation.
# Edit the @export arrays in the Inspector to change which items are injected
# and what inspection level / veil chance each one has.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const CargoScene := preload("res://game/cargo/cargo_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# Items that the player "won" at auction. Drag .tres files here.
@export var won_items: Array[ItemData] = []

# Inspection level per item, matched by index.
# 0 = veiled, 1 = untouched, 2 = browsed, 3 = examined, 4 = researched, 5 = authenticated.
# If shorter than won_items, remaining items default to 1 (untouched).
@export var inspection_levels: Array[int] = []

# Veil chance per item, matched by index (0.0–1.0).
# Only applies when inspection_level is 0; ignored otherwise.
# If shorter than won_items, remaining items default to 0.0.
@export var veil_chances: Array[float] = []

# Simulated amount paid at auction (shown in Block 06 settlement).
@export var paid_price: int = 1800

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_cargo_scene()

# ══ Setup helpers ══════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    const WAREHOUSE_LOTDATA = preload("uid://l8xrnjwietdt")
    const WAREHOUSE_LOCATION = preload("res://data/locations/warehouse_location.tres")

    var lot := LotEntry.create(WAREHOUSE_LOTDATA)
    RunManager.run_record = RunRecord.create(WAREHOUSE_LOCATION, SaveManager.load_active_car())
    RunManager.run_record.set_lot(lot)

    var entries: Array[ItemEntry] = RunManager.run_record.lot_entry.item_entries

    for entry in entries:
        entry.condition_inspect_level = 2
        entry.potential_inspect_level = 2
        entry.layer_index = 1

    # Simulate a won auction result using the built entries.
    RunManager.run_record.paid_price = paid_price
    RunManager.run_record.won_items = entries.duplicate()

    # Clear any leftover cargo from a previous run.
    RunManager.run_record.cargo_items.clear()


func _launch_cargo_scene() -> void:
    var scene: Control = CargoScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
