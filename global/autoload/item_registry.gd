# item_registry.gd
# Autoload that loads all ItemData resources at startup and provides query access.
# Access globally via ItemRegistry.get_items(rarity, category_id).
extends Node

var _items: Array[ItemData] = []

# Maps super_category_id (String) → Array[String] of category_id.
var _super_category_to_categories: Dictionary = {}


func _ready() -> void:
    _load_all_items()
    _build_super_category_index()


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


func _build_super_category_index() -> void:
    for item: ItemData in _items:
        if item.category_data == null or item.category_data.super_category == null:
            continue
        var sc_id: String = item.category_data.super_category.super_category_id
        var cat_id: String = item.category_data.category_id
        if not _super_category_to_categories.has(sc_id):
            _super_category_to_categories[sc_id] = []
        var cats: Array = _super_category_to_categories[sc_id]
        if not cats.has(cat_id):
            cats.append(cat_id)


# Returns all items matching the given rarity and category_id.
# Returns an empty array if none match.
func get_items(rarity: ItemData.Rarity, category_id: String) -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items:
        if item.rarity == rarity and item.category_data != null and item.category_data.category_id == category_id:
            result.append(item)
    return result


# Returns the list of category_ids that belong to the given super_category_id.
# Returns an empty array if the super_category_id is not found.
func get_categories_for_super(super_category_id: String) -> Array[String]:
    var result: Array[String] = []
    if _super_category_to_categories.has(super_category_id):
        for cat_id in _super_category_to_categories[super_category_id]:
            result.append(cat_id)
    return result


func get_all_items() -> Array[ItemData]:
    return _items


func get_item(item_id: String) -> ItemData:
    for item: ItemData in _items:
        if item.item_id == item_id:
            return item
    return null
