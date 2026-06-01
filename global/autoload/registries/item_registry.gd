# item_registry.gd
# Autoload that loads all ItemData resources at startup and provides query access.
# Access globally via ItemRegistry.get_item_by_id(item_id) / ItemRegistry.get_items(rarity, category_id).
# Category and super-category lookups live in CategoryRegistry and SuperCategoryRegistry.
extends ResourceRegistry


func _dir_path() -> String:
    return DataPaths.ITEMS_DIR


func _id_of(r: Resource) -> String:
    return (r as ItemData).item_id if r is ItemData else ""


# Returns all items matching the given rarity and category_id.
# Returns an empty array if none match.
func get_items(rarity: ItemData.Rarity, category_id: String) -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in get_all():
        if item.rarity == rarity and item.category_data != null and item.category_data.category_id == category_id:
            result.append(item)
    return result


func get_all_items() -> Array[ItemData]:
    var result: Array[ItemData] = []
    for item: ItemData in get_all():
        result.append(item)
    return result


func get_item_by_id(item_id: String) -> ItemData:
    return get_by_id(item_id) as ItemData
