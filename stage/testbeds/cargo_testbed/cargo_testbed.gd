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
    GameManager.item_entries.clear()

    var entries: Array[ItemEntry] = []
    for i: int in won_items.size():
        var level: int = inspection_levels[i] if i < inspection_levels.size() else 1
        var chance: float = veil_chances[i] if i < veil_chances.size() else 0.0
        var entry: ItemEntry = ItemEntry.create(won_items[i], chance if level == 0 else 0.0)
        # Override inspection_level after factory in case veil roll didn't fire.
        if level > 0:
            entry.inspection_level = level
        entries.append(entry)

    GameManager.item_entries = entries

    # Simulate a won auction result using the built entries.
    GameManager.lot_result = {
        &"paid_price": paid_price,
        &"won_items": entries.duplicate(),
    }

    # Clear any leftover cargo from a previous run.
    GameManager.cargo_items.clear()


func _launch_cargo_scene() -> void:
    var scene: Control = CargoScene.instantiate()
    add_child(scene)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
