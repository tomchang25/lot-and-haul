# cargo_testbed.gd
# Block 05 testbed — simulates a won auction and launches the cargo scene
# directly, bypassing Blocks 01–04.
#
# Run this scene to test cargo loading in isolation.
# Edit the @export arrays in the Inspector to change which items are injected
# and what inspection level each one has.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const CargoScene := preload("res://game/cargo/cargo_scene.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────

# Items that the player "won" at auction. Drag .tres files here.
@export var won_items: Array[ItemData] = []

# Inspection level per item, matched by index.
# 0 = untouched, 1 = browsed, 2 = examined.
# If shorter than won_items, remaining items default to 0.
@export var inspection_levels: Array[int] = []

# Simulated amount paid at auction (shown in Block 06 settlement).
@export var paid_price: int = 1800

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _inject_fake_state()
    _launch_cargo_scene()

# ══ Setup helpers ══════════════════════════════════════════════════════════════


func _inject_fake_state() -> void:
    # Build item_entries from the configured items and inspection levels.
    GameManager.item_entries.clear()
    for i: int in won_items.size():
        var entry := ItemEntry.new()
        entry.item_data = won_items[i]
        entry.inspection_level = inspection_levels[i] if i < inspection_levels.size() else 0
        GameManager.item_entries.append(entry)

    # Simulate a won auction result.
    GameManager.lot_result = {
        &"paid_price": paid_price,
        &"won_items": won_items.duplicate(),
    }

    # Clear any leftover cargo from a previous run.
    GameManager.cargo_items.clear()


func _launch_cargo_scene() -> void:
    var scene: Control = CargoScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
