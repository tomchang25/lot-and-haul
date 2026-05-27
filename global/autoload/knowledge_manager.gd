extends Node

enum KnowledgeAction {
    INSPECT = 1,
    REVEAL = 2,
    APPRAISE = 3,
    REPAIR = 4,
    SELL = 5,
    RESTORE = 6,
}

const _BASE_MASTERY: Dictionary = {
    KnowledgeAction.INSPECT: 2,
    KnowledgeAction.REVEAL: 1,
    KnowledgeAction.APPRAISE: 4,
    KnowledgeAction.REPAIR: 4,
    KnowledgeAction.SELL: 3,
    KnowledgeAction.RESTORE: 4,
}

const RANK_THRESHOLDS: Array[int] = [0, 100, 400, 1600, 6400, 25600]

const _ATTRIBUTE_UPGRADE_COST: int = 1000

var _perk_registry: Dictionary = { } # perk_id -> PerkData
var _attribute_registry: Dictionary = { } # attribute_id -> AttributeData


func _ready() -> void:
    _load_perk_registry()
    _load_attribute_registry()
    RegistryCoordinator.register(self)


func validate() -> bool:
    var ok := true
    if perk_count() == 0:
        push_error("KnowledgeManager: perk registry is empty")
        ok = false
    if attribute_count() == 0:
        push_error("KnowledgeManager: attribute registry is empty")
        ok = false
    for perk_id: String in SaveManager.unlocked_perks:
        if get_perk_by_id(perk_id) == null:
            push_error(
                "KnowledgeManager: SaveManager.unlocked_perks '%s' not found"
                % perk_id,
            )
            ok = false
    return ok


func add_category_points(category: CategoryData, rarity: ItemData.Rarity, action: KnowledgeAction) -> void:
    var base: int = _BASE_MASTERY[action]
    var rarity_mult: int = rarity + 1
    var gain: int = base * rarity_mult
    var category_id: String = category.category_id
    if not SaveManager.category_points.has(category_id):
        SaveManager.category_points[category_id] = 0
    SaveManager.category_points[category_id] += gain


func get_category_rank(category: CategoryData) -> int:
    var points: int = SaveManager.category_points.get(category.category_id, 0)
    if points >= 25600:
        return 5
    elif points >= 6400:
        return 4
    elif points >= 1600:
        return 3
    elif points >= 400:
        return 2
    elif points >= 100:
        return 1
    else:
        return 0


func get_super_category_rank(sc: SuperCategoryData) -> int:
    var total: int = 0
    for cat: CategoryData in SuperCategoryRegistry.get_categories_for_super(sc):
        total += get_category_rank(cat)
    return total


func get_mastery_rank() -> int:
    var total: int = 0
    for sc: SuperCategoryData in SuperCategoryRegistry.get_all_super_categories():
        total += get_super_category_rank(sc)
    return total


# -- Attribute registry ---------------------------------------------------------


func get_attribute_value(attribute_id: String) -> int:
    return SaveManager.attribute_levels.get(attribute_id, 1)


func get_attribute_by_id(attribute_id: String) -> AttributeData:
    return _attribute_registry.get(attribute_id, null)


func get_all_attributes() -> Array[AttributeData]:
    var result: Array[AttributeData] = []
    for attr: AttributeData in _attribute_registry.values():
        result.append(attr)
    return result


func attribute_count() -> int:
    return _attribute_registry.size()


func upgrade_attribute(attribute_id: String) -> bool:
    var attr: AttributeData = get_attribute_by_id(attribute_id)
    if attr == null:
        return false
    if SaveManager.cash < _ATTRIBUTE_UPGRADE_COST:
        return false
    SaveManager.cash -= _ATTRIBUTE_UPGRADE_COST
    var current := SaveManager.attribute_levels.get(attribute_id, attr.starting_value)
    SaveManager.attribute_levels[attribute_id] = current + 1
    SaveManager.save()
    return true


# -- Perk registry --------------------------------------------------------------


func unlock_perk(perk: PerkData) -> void:
    if SaveManager.unlocked_perks.has(perk.perk_id):
        return
    SaveManager.unlocked_perks.append(perk.perk_id)
    SaveManager.save()


func has_perk(perk: PerkData) -> bool:
    return perk.perk_id in SaveManager.unlocked_perks


func has_perk_by_id(perk_id: String) -> bool:
    return perk_id in SaveManager.unlocked_perks


func get_perk_by_id(perk_id: String) -> PerkData:
    return _perk_registry.get(perk_id, null)


func get_all_perks() -> Array[PerkData]:
    var result: Array[PerkData] = []
    for perk: PerkData in _perk_registry.values():
        result.append(perk)
    return result


func perk_count() -> int:
    return _perk_registry.size()


func _load_perk_registry() -> void:
    _perk_registry = ResourceDirLoader.load_by_id(
        DataPaths.PERKS_DIR,
        func(r: Resource) -> String:
            return (r as PerkData).perk_id if r is PerkData else ""
    )


func _load_attribute_registry() -> void:
    _attribute_registry = ResourceDirLoader.load_by_id(
        DataPaths.ATTRIBUTES_DIR,
        func(r: Resource) -> String:
            return (r as AttributeData).attribute_id if r is AttributeData else ""
    )
