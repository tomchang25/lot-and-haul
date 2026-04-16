# super_category_registry.gd
# Autoload that loads all SuperCategoryData resources at startup and provides
# query access, plus a pre-built super_category_id → Array[CategoryData] index.
# Access globally via SuperCategoryRegistry.get_super_category(id) /
# SuperCategoryRegistry.get_all_super_categories() /
# SuperCategoryRegistry.get_categories_for_super(id).
#
# Load-order note: depends on CategoryRegistry loading first. The assert in
# _ready will fire if project.godot is reordered incorrectly.
extends Node

var _super_categories: Dictionary = { }     # super_category_id → SuperCategoryData
var _categories_by_super: Dictionary = { }  # super_category_id → Array[CategoryData]


func _ready() -> void:
    _super_categories = ResourceDirLoader.load_by_id(
        DataPaths.SUPER_CATEGORIES_DIR,
        func(r: Resource) -> String:
            return (r as SuperCategoryData).super_category_id if r is SuperCategoryData else ""
    )
    assert(CategoryRegistry.size() > 0, "SuperCategoryRegistry requires CategoryRegistry to load first")
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
func get_super_category(super_category_id: String) -> SuperCategoryData:
    return _super_categories.get(super_category_id, null)


func get_all_super_categories() -> Array[SuperCategoryData]:
    var result: Array[SuperCategoryData] = []
    for sc: SuperCategoryData in _super_categories.values():
        result.append(sc)
    return result


func get_all_super_category_ids() -> Array[String]:
    var result: Array[String] = []
    for key: String in _super_categories.keys():
        result.append(key)
    return result


# Returns a duplicate of the member-category list for the given super-category,
# or an empty typed array if the super-category is unknown.
func get_categories_for_super(super_category_id: String) -> Array[CategoryData]:
    var list: Array[CategoryData] = _categories_by_super.get(
        super_category_id,
        [] as Array[CategoryData],
    )
    return list.duplicate()


func size() -> int:
    return _super_categories.size()
