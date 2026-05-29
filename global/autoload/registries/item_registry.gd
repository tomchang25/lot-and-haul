# item_registry.gd
# Autoload that loads all ItemData resources at startup and provides query access.
# Access globally via ItemRegistry.get_item_by_id(item_id) / ItemRegistry.get_items(rarity, category_id).
# Category and super-category lookups live in CategoryRegistry and SuperCategoryRegistry.
extends Node

var _items_by_id: Dictionary = { } # item_id → ItemData


func _ready() -> void:
    _items_by_id = ResourceDirLoader.load_by_id(
        DataPaths.ITEMS_DIR,
        func(r: Resource) -> String:
            return (r as ItemData).item_id if r is ItemData else ""
    )
    RegistryCoordinator.register(self)


func validate() -> bool:
    if size() == 0:
        push_error("ItemRegistry: registry is empty")
        return false
    return true


# Returns all items matching the given rarity and category_id.
# Returns an empty array if none match.
func get_items(rarity: ItemData.Rarity, category_id: String) -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items_by_id.values():
        if item.rarity == rarity and item.category_data != null and item.category_data.category_id == category_id:
            result.append(item)
    return result


func get_all_items() -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in _items_by_id.values():
        result.append(item)
    return result


func get_item_by_id(item_id: String) -> ItemData:
    return _items_by_id.get(item_id, null)


func size() -> int:
    return _items_by_id.size()
