extends Node

enum KnowledgeAction {
    POTENTIAL_INSPECT,
    CONDITION_INSPECT,
    REVEAL,
    APPRAISE,
    REPAIR,
    SELL,
}

const _BASE_EXP: Dictionary = {
    KnowledgeAction.POTENTIAL_INSPECT: 2,
    KnowledgeAction.CONDITION_INSPECT: 2,
    KnowledgeAction.REVEAL: 1,
    KnowledgeAction.APPRAISE: 4,
    KnowledgeAction.REPAIR: 4,
    KnowledgeAction.SELL: 3,
}


func add_exp(category_id: String, rarity: ItemData.Rarity, action: KnowledgeAction) -> void:
    var base: int = _BASE_EXP[action]
    var rarity_mult: int = rarity + 1 # COMMON=0→1, UNCOMMON=1→2, …, LEGENDARY=4→5
    var gain: int = base * rarity_mult
    if not SaveManager.exp.has(category_id):
        SaveManager.exp[category_id] = 0
    SaveManager.exp[category_id] += gain


func get_category_level(category_id: String) -> int:
    var exp_val: int = SaveManager.exp.get(category_id, 0)
    if exp_val >= 25600:
        return 5
    elif exp_val >= 6400:
        return 4
    elif exp_val >= 1600:
        return 3
    elif exp_val >= 400:
        return 2
    elif exp_val >= 100:
        return 1
    else:
        return 0


func get_super_category_level(super_category_id: String) -> int:
    var total: int = 0
    for cat_id: String in ItemRegistry.get_categories_for_super(super_category_id):
        total += get_category_level(cat_id)
    return total


func get_price_range(super_category_id: String, rarity: ItemData.Rarity) -> Vector2:
    var level: int = get_super_category_level(super_category_id)

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

    var progress: float = minf(float(level) / float(threshold), 1.0)
    if progress >= 1.0:
        return Vector2(1.0, 1.0)

    var effective_min_w: float = min_full_w * (1.0 - progress)
    var effective_max_w: float = max_full_w * (1.0 - progress)

    var knowledge_min: float = randf_range(1.0 - effective_min_w, 1.0)
    var knowledge_max: float = randf_range(1.0, 1.0 + effective_max_w)

    return Vector2(knowledge_min, knowledge_max)


# Flat skill registry. Returns the player's current level for the given skill.
# Always 1 for this slice — full skill progression is deferred.
func get_level(skill_id: String) -> int:
    return 1


# True if the player can advance the entry to the next identity layer.
# Checks stamina cost and skill prerequisite via KnowledgeManager.
func can_advance(entry: ItemEntry, context: LayerUnlockAction.ActionContext) -> bool:
    var action: LayerUnlockAction = entry.current_unlock_action()
    if action == null:
        return false

    if entry.is_at_final_layer():
        return false

    if action.context == LayerUnlockAction.ActionContext.AUTO:
        return false

    if action.context != context:
        return false

    # TODO: Remove it when implemented. Advance to the next layer requires time in home instead stamina in auction.
    # if RunManager.run_record.stamina < action.stamina_cost:
    #     return false

    if not action.required_skill:
        return true

    return get_level(action.required_skill.skill_id) >= action.required_level
