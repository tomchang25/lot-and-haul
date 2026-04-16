# category_registry.gd
# Autoload that loads all CategoryData resources at startup and provides query
# access. Access globally via CategoryRegistry.get_category(category_id) /
# CategoryRegistry.get_all_categories().
extends Node

var _categories: Dictionary = { } # category_id → CategoryData


func _ready() -> void:
    _categories = ResourceDirLoader.load_by_id(
        DataPaths.CATEGORIES_DIR,
        func(r: Resource) -> String:
            return (r as CategoryData).category_id if r is CategoryData else ""
    )


# Returns the CategoryData with the given category_id, or null if not found.
func get_category(category_id: String) -> CategoryData:
    return _categories.get(category_id, null)


func get_all_categories() -> Array[CategoryData]:
    var result: Array[CategoryData] = []
    for cat: CategoryData in _categories.values():
        result.append(cat)
    return result


func get_all_category_ids() -> Array[String]:
    var result: Array[String] = []
    for key: String in _categories.keys():
        result.append(key)
    return result


# Looks up the super-category for the given category_id via the direct
# CategoryData.super_category reference. Returns null if the category is
# missing or has no super-category reference.
func get_super_category_for(category_id: String) -> SuperCategoryData:
    var cat: CategoryData = _categories.get(category_id, null)
    if cat == null:
        return null
    return cat.super_category


func size() -> int:
    return _categories.size()
