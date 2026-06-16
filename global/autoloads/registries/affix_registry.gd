# affix_registry.gd
# Autoload that loads all AffixData resources at startup and provides query access.
# Access globally via AffixRegistry.get_affix_by_id(affix_id).
extends ResourceRegistry

var _category_to_affixes: Dictionary = { }
var _affix_to_clue_ids: Dictionary = { }
var _affix_index_built: bool = false


func _dir_path() -> String:
    return DataPaths.AFFIXES_DIR


func _id_of(r: Resource) -> String:
    return (r as AffixData).affix_id if r is AffixData else ""


func get_affix_by_id(affix_id: String) -> AffixData:
    return get_by_id(affix_id) as AffixData


func get_all_affixes() -> Array[AffixData]:
    var result: Array[AffixData] = []
    for affix: AffixData in get_all():
        result.append(affix)
    return result


func get_affixes_for_category(category) -> Array:
    _ensure_affix_query_index()
    return _category_to_affixes.get(category, []).duplicate()


func get_clue_ids_for_affix(affix) -> Array[String]:
    _ensure_affix_query_index()
    return _affix_to_clue_ids.get(affix, []).duplicate()


func get_all_combination_clue_ids() -> Array[String]:
    _ensure_affix_query_index()
    var result: Array[String] = []
    for clue_ids: Array[String] in _affix_to_clue_ids.values():
        for clue_id in clue_ids:
            if clue_id not in result:
                result.append(clue_id)
    return result


func _guard_affix_query_deps() -> bool:
    if CategoryRegistry.size() == 0:
        ToastManager.show_dev_error("AffixRegistry: CategoryRegistry not loaded")
        return false
    if ClueRegistry.size() == 0:
        ToastManager.show_dev_error("AffixRegistry: ClueRegistry not loaded")
        return false
    return true


func _ensure_affix_query_index() -> void:
    if _affix_index_built:
        return
    if not _guard_affix_query_deps():
        return
    _affix_index_built = true

    var all_categories: Array = []
    for category in CategoryRegistry.get_all_categories():
        all_categories.append(category)
        _category_to_affixes[category] = []

    for affix in get_all_affixes():
        var scoped_categories: Array = []
        if affix.scope_mode == "all":
            scoped_categories.assign(all_categories)
        else:
            scoped_categories.assign(affix.category_scope)

        for category in scoped_categories:
            _category_to_affixes[category].append(affix)

        var clue_ids: Array[String] = []
        for combination in affix.combinations:
            for clue in combination.surface_clues + combination.hidden_clues:
                if clue.clue_id not in clue_ids:
                    clue_ids.append(clue.clue_id)
        _affix_to_clue_ids[affix] = clue_ids
