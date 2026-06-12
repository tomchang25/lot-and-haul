# super_category_registry.gd
# Autoload that loads all SuperCategoryData resources at startup and provides
# query access, plus a pre-built super_category_id → Array[CategoryData] index.
# Access globally via SuperCategoryRegistry.get_super_category_by_id(id) /
# SuperCategoryRegistry.get_all_super_categories() /
# SuperCategoryRegistry.get_categories_for_super(sc).
#
# Load-order note: depends on CategoryRegistry loading first. The guard in
# _ready will fire if project.godot is reordered incorrectly.
extends ResourceRegistry

var _categories_by_super: Dictionary = { } # super_category_id → Array[CategoryData]


func _dir_path() -> String:
    return DataPaths.SUPER_CATEGORIES_DIR


func _id_of(r: Resource) -> String:
    return (r as SuperCategoryData).super_category_id if r is SuperCategoryData else ""


func _ready() -> void:
    super._ready()

    if CategoryRegistry.size() <= 0:
        ToastManager.show_dev_error("SuperCategoryRegistry requires CategoryRegistry to load first")
        return

    _build_categories_by_super_index()


func _build_categories_by_super_index() -> void:
    for cat: CategoryData in CategoryRegistry.get_all_categories():
        if cat.super_category == null:
            continue
        var sc_id: String = cat.super_category.super_category_id
        var list: Array[CategoryData] = _categories_by_super.get(sc_id, [] as Array[CategoryData])
        list.append(cat)
        _categories_by_super[sc_id] = list


# Returns the SuperCategoryData with the given super_category_id, or null.
func get_super_category_by_id(super_category_id: String) -> SuperCategoryData:
    return get_by_id(super_category_id) as SuperCategoryData


func get_all_super_categories() -> Array[SuperCategoryData]:
    var result: Array[SuperCategoryData] = []
    for sc: SuperCategoryData in get_all():
        result.append(sc)
    return result


# Returns a duplicate of the member-category list for the given super-category,
# or an empty typed array if the super-category is unknown.
func get_categories_for_super(sc: SuperCategoryData) -> Array[CategoryData]:
    var list: Array[CategoryData] = _categories_by_super.get(
        sc.super_category_id,
        [] as Array[CategoryData],
    )
    return list.duplicate()
