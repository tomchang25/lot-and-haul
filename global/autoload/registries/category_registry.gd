# category_registry.gd
# Autoload that loads all CategoryData resources at startup and provides query
# access. Access globally via CategoryRegistry.get_category_by_id(category_id) /
# CategoryRegistry.get_all_categories().
extends Node

var _categories: Dictionary = { } # category_id → CategoryData


func _ready() -> void:
    _categories = ResourceDirLoader.load_by_id(
        DataPaths.CATEGORIES_DIR,
        func(r: Resource) -> String:
            return (r as CategoryData).category_id if r is CategoryData else ""
    )
    RegistryCoordinator.register(self)


func migrate() -> void:
    for key in SaveManager.category_points.keys():
        if get_category_by_id(key) == null:
            push_warning("CategoryRegistry.migrate: dropping unknown category_points key '%s'" % key)
            SaveManager.category_points.erase(key)

    for key: String in MarketManager.category_factors_today.keys():
        if get_category_by_id(key) == null:
            push_warning("CategoryRegistry.migrate: dropping unknown category_points key '%s'" % key)
            MarketManager.category_factors_today.erase(key)

func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("CategoryRegistry: registry is empty")
        ok = false
    for category_id: String in SaveManager.category_points.keys():
        if get_category_by_id(category_id) == null:
            push_error(
                "CategoryRegistry: SaveManager.category_points key '%s' not found"
                % category_id,
            )
            ok = false
    for category_id: String in MarketManager.category_factors_today.keys():
        if get_category_by_id(category_id) == null:
            push_error(
                "CategoryRegistry: MarketManager.category_factors_today key '%s' not found"
                % category_id,
            )
            ok = false
    return ok


# Returns the CategoryData with the given category_id, or null if not found.
func get_category_by_id(category_id: String) -> CategoryData:
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


func size() -> int:
    return _categories.size()
