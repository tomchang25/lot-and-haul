# item_registry.gd
# Autoload that loads all ItemData resources at startup and provides query access.
# Access globally via ItemRegistry.get_items(rarity, category_id).
extends Node

var _items: Array[ItemData] = []


func _ready() -> void:
    _load_all_items()


func _load_all_items() -> void:
    var dir := DirAccess.open("res://data/items")
    if dir == null:
        push_error("ItemRegistry: could not open res://data/items")
        return

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path := "res://data/items/" + file_name
            var resource := load(path)
            if resource is ItemData:
                _items.append(resource as ItemData)
        file_name = dir.get_next()
    dir.list_dir_end()


# Returns all items matching the given rarity and category_id.
# Returns an empty array if none match.
func get_items(rarity: ItemData.Rarity, category_id: String) -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items:
        if item.rarity == rarity and item.category_data != null and item.category_data.category_id == category_id:
            result.append(item)
    return result
