extends Node

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

var _perk_registry: Dictionary = { } # perk_id → PerkData


func _ready() -> void:
    _load_perk_registry()


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


func get_mastery_rank(super_category_id: String) -> int:
    var total: int = 0
    for cat_id: String in ItemRegistry.get_categories_for_super(super_category_id):
        total += get_category_rank(cat_id)
    return total


func get_price_range(super_category_id: String, rarity: ItemData.Rarity, layer_depth: int = 0) -> Vector2:
    var rank: int = get_mastery_rank(super_category_id)

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
