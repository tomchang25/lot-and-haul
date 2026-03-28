extends Node

# Current lot of 4 items placed in the warehouse scene (set before inspection begins).
var current_lot: Array[ItemData] = []

# Maps each ItemData → { "level": int, "clues_revealed": int }
# Written by the inspection block; read by all subsequent blocks.
var inspection_results: Dictionary = { }

# Written by Block 04 (Auction).
# { "paid_price": int, "won_items": Array[ItemData] }
# paid_price = 0 and won_items = [] when the player passes or loses.
var lot_result: Dictionary = { }


func _ready() -> void:
    if current_lot.is_empty():
        _init_default_lot()


# Populates the lot with the first four items for the vertical slice.
func _init_default_lot() -> void:
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
