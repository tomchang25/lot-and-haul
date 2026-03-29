extends Node

@export var scenes: SceneRegistry

# Current lot of 4 items placed in the warehouse scene (set before inspection begins).
var current_lot: Array[ItemData] = []

# Maps each ItemData → { "level": int, "clues_revealed": int }
# Written by the inspection block; read by all subsequent blocks.
var inspection_results: Dictionary = { }

# Written by Block 04 (Auction).
# { "paid_price": int, "won_items": Array[ItemData] }
# paid_price = 0 and won_items = [] when the player passes or loses.
var lot_result: Dictionary = { }

# Written by Block 05 (Cargo Loading).
# The subset of won_items the player chose to bring home.
var cargo_items: Array[ItemData] = []

# Written by Block 06 (Home Appraisal).
# { "sell_value": int, "paid_price": int, "net": int }
var run_result: Dictionary = { }


func _ready() -> void:
    if current_lot.is_empty():
        _init_default_lot()


func go_to_auction() -> void:
    get_tree().change_scene_to_packed(scenes.auction)


func go_to_cargo() -> void:
    get_tree().change_scene_to_packed(scenes.cargo)


func go_to_appraisal() -> void:
    get_tree().change_scene_to_packed(scenes.appraisal)

# func go_to_home() -> void:
#     get_tree().change_scene_to_packed(scenes.home)


func restart_run() -> void:
    inspection_results.clear()
    lot_result = { }
    cargo_items.clear()
    run_result = { }
    _init_default_lot()
    get_tree().change_scene_to_packed(scenes.inspection)


# Populates the lot with the first four items for the vertical slice.
func _init_default_lot() -> void:
    current_lot.clear()
    var paths: Array[String] = [
        "res://data/items/brass_lamp.tres",
        "res://data/items/pocket_watch.tres",
        "res://data/items/oil_painting.tres",
        "res://data/items/wooden_clock.tres",
    ]
    for path in paths:
        var item := load(path) as ItemData
        if item:
            current_lot.append(item)
