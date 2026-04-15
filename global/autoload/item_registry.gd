# item_registry.gd
# Autoload that loads all ItemData resources at startup and provides query access.
# Access globally via ItemRegistry.get_items(rarity, category_id).
extends Node

var _items_by_id: Dictionary = { } # item_id → ItemData

# Maps super_category_id (String) → Array[String] of category_id.
var _super_category_to_categories: Dictionary = { }

# Maps super_category_id (String) → SuperCategoryData resource.
var _super_categories_by_id: Dictionary = { }


func _ready() -> void:
    _items_by_id = ResourceDirLoader.load_by_id(
        DataPaths.ITEMS_DIR,
        func(r: Resource) -> String:
            return (r as ItemData).item_id if r is ItemData else ""
    )
    _build_super_category_index()


func _build_super_category_index() -> void:
    for item: ItemData in _items_by_id.values():
        if item.category_data == null or item.category_data.super_category == null:
            continue
        var sc: SuperCategoryData = item.category_data.super_category
        var sc_id: String = sc.super_category_id
        var cat_id: String = item.category_data.category_id
        if not _super_category_to_categories.has(sc_id):
            _super_category_to_categories[sc_id] = []
        var cats: Array = _super_category_to_categories[sc_id]
        if not cats.has(cat_id):
            cats.append(cat_id)
        if not _super_categories_by_id.has(sc_id):
            _super_categories_by_id[sc_id] = sc


# Returns all items matching the given rarity and category_id.
# Returns an empty array if none match.
func get_items(rarity: ItemData.Rarity, category_id: String) -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items_by_id.values():
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


func get_all_super_category_ids() -> Array[String]:
    var result: Array[String] = []
    for key in _super_category_to_categories.keys():
        result.append(key)
    return result


func get_all_items() -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items_by_id.values():
        result.append(item)
    return result


func get_super_category_display_name(super_category_id: String) -> String:
    for item: ItemData in _items_by_id.values():
        if item.category_data != null and item.category_data.super_category != null:
            if item.category_data.super_category.super_category_id == super_category_id:
                return item.category_data.super_category.display_name
    return super_category_id


func get_category_display_name(category_id: String) -> String:
    for item: ItemData in _items_by_id.values():
        if item.category_data != null and item.category_data.category_id == category_id:
            return item.category_data.display_name
    return category_id


func get_super_category_data(super_category_id: String) -> SuperCategoryData:
    return _super_categories_by_id.get(super_category_id, null)


func get_all_category_ids() -> Array[String]:
    var seen: Dictionary = { }
    var result: Array[String] = []
    for item: ItemData in _items_by_id.values():
        if item.category_data == null:
            continue
        var cat_id: String = item.category_data.category_id
        if not seen.has(cat_id):
            seen[cat_id] = true
            result.append(cat_id)
    return result


func get_category_data(category_id: String) -> CategoryData:
    for item: ItemData in _items_by_id.values():
        if item.category_data != null and item.category_data.category_id == category_id:
            return item.category_data
    return null


func get_item(item_id: String) -> ItemData:
    return _items_by_id.get(item_id, null)


func size() -> int:
    return _items_by_id.size()
