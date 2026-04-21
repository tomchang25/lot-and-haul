extends Node

enum AdvanceCheck {
    OK,
    NO_ACTION,
    INSUFFICIENT_CATEGORY_RANK,
    INSUFFICIENT_SKILL,
    MISSING_PERK,
}

enum UpgradeResult {
    OK,
    MAX_LEVEL,
    INSUFFICIENT_SUPER_CATEGORY_RANK,
    INSUFFICIENT_MASTERY_RANK,
    INSUFFICIENT_CASH,
}

enum KnowledgeAction {
    INSPECT = 1,
    REVEAL = 2,
    APPRAISE = 3,
    REPAIR = 4,
    SELL = 5,
}

const _BASE_MASTERY: Dictionary = {
    KnowledgeAction.INSPECT: 2,
    KnowledgeAction.REVEAL: 1,
    KnowledgeAction.APPRAISE: 4,
    KnowledgeAction.REPAIR: 4,
    KnowledgeAction.SELL: 3,
}

const RANK_THRESHOLDS: Array[int] = [0, 100, 400, 1600, 6400, 25600]

var _perk_registry: Dictionary = { } # perk_id → PerkData
var _skill_registry: Dictionary = { } # skill_id → SkillData


func _ready() -> void:
    _load_perk_registry()
    _load_skill_registry()
    RegistryCoordinator.register(self)


func validate() -> bool:
    var ok := true
    if perk_count() == 0:
        push_error("KnowledgeManager: perk registry is empty")
        ok = false
    if skill_count() == 0:
        push_error("KnowledgeManager: skill registry is empty")
        ok = false
    for perk_id: String in SaveManager.unlocked_perks:
        if get_perk_by_id(perk_id) == null:
            push_error(
                "KnowledgeManager: SaveManager.unlocked_perks '%s' not found"
                % perk_id,
            )
            ok = false
    for skill_id: String in SaveManager.skill_levels.keys():
        if get_skill_by_id(skill_id) == null:
            push_error(
                "KnowledgeManager: SaveManager.skill_levels key '%s' not found"
                % skill_id,
            )
            ok = false
    return ok


func add_category_points(category_id: String, rarity: ItemData.Rarity, action: KnowledgeAction) -> void:
    var base: int = _BASE_MASTERY[action]
    var rarity_mult: int = rarity + 1 # COMMON=0→1, UNCOMMON=1→2, …, LEGENDARY=4→5
    var gain: int = base * rarity_mult
    if not SaveManager.category_points.has(category_id):
        SaveManager.category_points[category_id] = 0
    SaveManager.category_points[category_id] += gain


func get_category_rank(category_id: String) -> int:
    var points: int = SaveManager.category_points.get(category_id, 0)
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


func get_super_category_rank(super_category_id: String) -> int:
    var total: int = 0
    for cat: CategoryData in SuperCategoryRegistry.get_categories_for_super(super_category_id):
        total += get_category_rank(cat.category_id)
    return total


func get_mastery_rank() -> int:
    var total: int = 0
    for sc: SuperCategoryData in SuperCategoryRegistry.get_all_super_categories():
        total += get_super_category_rank(sc.super_category_id)
    return total


func get_level(skill: SkillData) -> int:
    return SaveManager.skill_levels.get(skill.skill_id, 0)


func get_skill_by_id(skill_id: String) -> SkillData:
    return _skill_registry.get(skill_id, null)


func get_all_skills() -> Array[SkillData]:
    var result: Array[SkillData] = []
    for skill: SkillData in _skill_registry.values():
        result.append(skill)
    return result


func _check_upgrade(skill: SkillData) -> UpgradeResult:
    if skill == null:
        return UpgradeResult.MAX_LEVEL
    var current: int = get_level(skill)
    if current >= skill.levels.size():
        return UpgradeResult.MAX_LEVEL
    var next: SkillLevelData = skill.levels[current]
    for super_id: String in next.required_super_category_ranks:
        var min_rank: int = int(next.required_super_category_ranks[super_id])
        if get_super_category_rank(super_id) < min_rank:
            return UpgradeResult.INSUFFICIENT_SUPER_CATEGORY_RANK
    if get_mastery_rank() < next.required_mastery_rank:
        return UpgradeResult.INSUFFICIENT_MASTERY_RANK
    if SaveManager.cash < next.cash_cost:
        return UpgradeResult.INSUFFICIENT_CASH
    return UpgradeResult.OK


func peek_upgrade(skill: SkillData) -> UpgradeResult:
    return _check_upgrade(skill)


func try_upgrade_skill(skill: SkillData) -> UpgradeResult:
    var result: UpgradeResult = _check_upgrade(skill)
    if result != UpgradeResult.OK:
        return result
    var current: int = get_level(skill)
    var next: SkillLevelData = skill.levels[current]
    SaveManager.cash -= next.cash_cost
    SaveManager.skill_levels[skill.skill_id] = current + 1
    SaveManager.save()
    return UpgradeResult.OK


func can_advance(entry: ItemEntry) -> AdvanceCheck:
    var action: LayerUnlockAction = entry.current_unlock_action()
    if action == null or entry.is_at_final_layer():
        return AdvanceCheck.NO_ACTION

    if action.required_category_rank > 0:
        if get_category_rank(entry.item_data.category_data.category_id) < action.required_category_rank:
            return AdvanceCheck.INSUFFICIENT_CATEGORY_RANK

    if action.required_skill != null:
        if get_level(action.required_skill) < action.required_level:
            return AdvanceCheck.INSUFFICIENT_SKILL

    if action.required_perk != null:
        if not has_perk(action.required_perk):
            return AdvanceCheck.MISSING_PERK

    return AdvanceCheck.OK

# ══ Perk registry ════════════════════════════════════════════════════════════


func unlock_perk(perk: PerkData) -> void:
    if SaveManager.unlocked_perks.has(perk.perk_id):
        return
    SaveManager.unlocked_perks.append(perk.perk_id)
    SaveManager.save()


func has_perk(perk: PerkData) -> bool:
    return perk.perk_id in SaveManager.unlocked_perks


func get_perk_by_id(perk_id: String) -> PerkData:
    return _perk_registry.get(perk_id, null)


func get_all_perks() -> Array[PerkData]:
    var result: Array[PerkData] = []
    for perk: PerkData in _perk_registry.values():
        result.append(perk)
    return result


func perk_count() -> int:
    return _perk_registry.size()


func skill_count() -> int:
    return _skill_registry.size()


func _load_perk_registry() -> void:
    _perk_registry = ResourceDirLoader.load_by_id(
        DataPaths.PERKS_DIR,
        func(r: Resource) -> String:
            return (r as PerkData).perk_id if r is PerkData else ""
    )


func _load_skill_registry() -> void:
    _skill_registry = ResourceDirLoader.load_by_id(
        DataPaths.SKILLS_DIR,
        func(r: Resource) -> String:
            return (r as SkillData).skill_id if r is SkillData else ""
    )
