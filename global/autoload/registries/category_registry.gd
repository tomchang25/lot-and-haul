# category_registry.gd
# Autoload that loads all CategoryData resources at startup and provides query
# access. Access globally via CategoryRegistry.get_category_by_id(category_id) /
# CategoryRegistry.get_all_categories().
extends ResourceRegistry


func _dir_path() -> String:
    return DataPaths.CATEGORIES_DIR


func _id_of(r: Resource) -> String:
    return (r as CategoryData).category_id if r is CategoryData else ""


func migrate() -> void:
    for key in KnowledgeManager.get_tracked_category_ids():
        if get_category_by_id(key) == null:
            push_warning("CategoryRegistry.migrate: dropping unknown category_points key '%s'" % key)
            KnowledgeManager.erase_category_points(key)


func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("CategoryRegistry: registry is empty")
        ok = false
    for category_id: String in KnowledgeManager.get_tracked_category_ids():
        if get_category_by_id(category_id) == null:
            push_error(
                "CategoryRegistry: KnowledgeManager.category_points key '%s' not found"
                % category_id,
            )
            ok = false
    return ok


# Returns the CategoryData with the given category_id, or null if not found.
func get_category_by_id(category_id: String) -> CategoryData:
    return get_by_id(category_id) as CategoryData


func get_all_categories() -> Array[CategoryData]:
    var result: Array[CategoryData] = []
    for cat: CategoryData in get_all():
        result.append(cat)
    return result
