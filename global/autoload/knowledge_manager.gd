extends Node

enum AdvanceCheck {
    OK,
    NO_ACTION,
    WRONG_CONTEXT,
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
    POTENTIAL_INSPECT,
    CONDITION_INSPECT,
    REVEAL,
    APPRAISE,
    REPAIR,
    SELL,
}

const _BASE_MASTERY: Dictionary = {
    KnowledgeAction.POTENTIAL_INSPECT: 2,
    KnowledgeAction.CONDITION_INSPECT: 2,
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
    for cat_id: String in ItemRegistry.get_categories_for_super(super_category_id):
        total += get_category_rank(cat_id)
    return total


func get_mastery_rank() -> int:
    var total: int = 0
    for sc_id: String in ItemRegistry.get_all_super_category_ids():
        total += get_super_category_rank(sc_id)
    return total


func get_price_range(super_category_id: String, rarity: ItemData.Rarity, layer_depth: int = 0) -> Vector2:
    var rank: int = get_super_category_rank(super_category_id)

    var threshold: int
    var min_full_w: float
    var max_full_w: float

    match rarity:
        ItemData.Rarity.COMMON:
            return Vector2(1.0, 1.0)
        ItemData.Rarity.UNCOMMON:
            threshold = 20
            min_full_w = 0.50
            max_full_w = 1.00
        ItemData.Rarity.RARE:
            threshold = 50
            min_full_w = 0.67
            max_full_w = 2.00
        ItemData.Rarity.EPIC:
            threshold = 100
            min_full_w = 0.75
            max_full_w = 3.00
        ItemData.Rarity.LEGENDARY:
            threshold = 200
            min_full_w = 0.80
            max_full_w = 4.00
        _:
            return Vector2(1.0, 1.0)

    var effective_threshold: int = threshold * (1 + layer_depth)
    var progress: float = minf(float(rank) / float(effective_threshold), 1.0)
    if progress >= 1.0:
        return Vector2(1.0, 1.0)

    var effective_min_w: float = min_full_w * (1.0 - progress)
    var effective_max_w: float = max_full_w * (1.0 - progress)

    var rank_min: float = randf_range(1.0 - effective_min_w, 1.0)
    var rank_max: float = randf_range(1.0, 1.0 + effective_max_w)

    return Vector2(rank_min, rank_max)


func apply_market_research(entry: ItemEntry) -> void:
    var super_cat_id: String = \
    entry.item_data.category_data.super_category.super_category_id
    var layers_count: int = entry.item_data.identity_layers.size()

    var old_range: float = 0.0
    for i in range(layers_count):
        old_range += entry.knowledge_max[i] - entry.knowledge_min[i]

    var new_min: Array[float] = []
    var new_max: Array[float] = []
    new_min.resize(layers_count)
    new_max.resize(layers_count)
    for i in range(layers_count):
        var depth: int = maxi(0, i - entry.layer_index)
        var price_range: Vector2 = get_price_range(
            super_cat_id,
            entry.item_data.rarity,
            depth,
        )
        new_min[i] = price_range.x
        new_max[i] = price_range.y

    var new_range: float = 0.0
    for i in range(layers_count):
        new_range += new_max[i] - new_min[i]

    if new_range < old_range:
        entry.knowledge_min = new_min
        entry.knowledge_max = new_max


func get_level(skill_id: String) -> int:
    return SaveManager.skill_levels.get(skill_id, 0)


func get_skill(skill_id: String) -> SkillData:
    return _skill_registry.get(skill_id, null)


func get_all_skills() -> Array[SkillData]:
    var result: Array[SkillData] = []
    for skill: SkillData in _skill_registry.values():
        result.append(skill)
    return result


func _check_upgrade(skill_id: String) -> UpgradeResult:
    var skill: SkillData = _skill_registry.get(skill_id, null)
    if skill == null:
        return UpgradeResult.MAX_LEVEL
    var current: int = get_level(skill_id)
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


func peek_upgrade(skill_id: String) -> UpgradeResult:
    return _check_upgrade(skill_id)


func try_upgrade_skill(skill_id: String) -> UpgradeResult:
    var result: UpgradeResult = _check_upgrade(skill_id)
    if result != UpgradeResult.OK:
        return result
    var skill: SkillData = _skill_registry[skill_id]
    var current: int = get_level(skill_id)
    var next: SkillLevelData = skill.levels[current]
    SaveManager.cash -= next.cash_cost
    SaveManager.skill_levels[skill_id] = current + 1
    SaveManager.save()
    return UpgradeResult.OK


func can_advance(entry: ItemEntry, context: LayerUnlockAction.ActionContext) -> AdvanceCheck:
    var action: LayerUnlockAction = entry.current_unlock_action()
    if action == null or entry.is_at_final_layer():
        return AdvanceCheck.NO_ACTION

    if action.context == LayerUnlockAction.ActionContext.AUTO:
        return AdvanceCheck.NO_ACTION

    if action.context != context:
        return AdvanceCheck.WRONG_CONTEXT

    if action.required_category_rank > 0:
        if get_category_rank(entry.item_data.category_data.category_id) < action.required_category_rank:
            return AdvanceCheck.INSUFFICIENT_CATEGORY_RANK

    if action.required_skill != null:
        if get_level(action.required_skill.skill_id) < action.required_level:
            return AdvanceCheck.INSUFFICIENT_SKILL

    if action.required_perk_id != "":
        if not has_perk(action.required_perk_id):
            return AdvanceCheck.MISSING_PERK

    return AdvanceCheck.OK

# ══ Perk registry ════════════════════════════════════════════════════════════


func unlock_perk(perk_id: String) -> void:
    if SaveManager.unlocked_perks.has(perk_id):
        return
    SaveManager.unlocked_perks.append(perk_id)
    SaveManager.save()


func has_perk(perk_id: String) -> bool:
    return SaveManager.unlocked_perks.has(perk_id)


func get_perk(perk_id: String) -> PerkData:
    return _perk_registry.get(perk_id, null)


func get_all_perks() -> Array[PerkData]:
    var result: Array[PerkData] = []
    for perk: PerkData in _perk_registry.values():
        result.append(perk)
    return result


func _load_perk_registry() -> void:
    var dir := DirAccess.open("res://data/perks")
    if dir == null:
        return
    dir.list_dir_begin()
    var filename: String = dir.get_next()
    while filename != "":
        if filename.ends_with(".tres"):
            var path := "res://data/perks/" + filename
            var perk := ResourceLoader.load(path) as PerkData
            if perk != null and perk.perk_id != "":
                _perk_registry[perk.perk_id] = perk
        filename = dir.get_next()
    dir.list_dir_end()


func _load_skill_registry() -> void:
    var dir := DirAccess.open("res://data/skills")
    if dir == null:
        return
    dir.list_dir_begin()
    var filename: String = dir.get_next()
    while filename != "":
        if filename.ends_with(".tres"):
            var path := "res://data/skills/" + filename
            var skill := ResourceLoader.load(path) as SkillData
            if skill != null and skill.skill_id != "":
                _skill_registry[skill.skill_id] = skill
        filename = dir.get_next()
    dir.list_dir_end()
