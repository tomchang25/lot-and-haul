# knowledge_manager.gd
# Knowledge progression: category mastery, attribute levels, and unlocked perks.
# Delegates persistent state to KnowledgeStore. Registers the Store with SaveManager.
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

# ── Store (persistent state) ──────────────────────────────────────────────────

var _knowledge: KnowledgeStore

# ── Registry (non-persistent) ─────────────────────────────────────────────────

var _perk_registry: Dictionary = { } # perk_id → PerkData
var _attribute_registry: Dictionary = { } # attribute_id → AttributeData


func _ready() -> void:
    _load_perk_registry()
    _load_attribute_registry()
    _knowledge = KnowledgeStore.new()
    SaveManager.register_provider(self)

    # Subscribe to hub-phase business events emitted by MetaManager so mastery
    # XP accrues without a direct import dependency (cycle-free).
    EventBus.sale_resolved.connect(_on_sale_resolved)
    EventBus.item_repaired.connect(_on_item_repaired)
    EventBus.item_restored.connect(_on_item_restored)

# ── Registry validation ────────────────────────────────────────────────────────


func validate() -> bool:
    var ok := true
    if perk_count() == 0:
        push_error("KnowledgeManager: perk registry is empty")
        ok = false
    if attribute_count() == 0:
        push_error("KnowledgeManager: attribute registry is empty")
        ok = false
    for perk_id: String in _knowledge.unlocked_perks:
        if get_perk_by_id(perk_id) == null:
            push_error(
                "KnowledgeManager: unlocked_perks '%s' not found" % perk_id,
            )
            ok = false
    ok = _knowledge.validate() and ok
    return ok

# ══ Save section interface ════════════════════════════════════════════════════


## Serializes KnowledgeManager state into a flat dict with the knowledge section key.
func to_dict() -> Dictionary:
    var out: Dictionary = { }
    out[_knowledge.section_id()] = _knowledge.to_dict()
    return out


## Restores KnowledgeManager state from the full sections dict.
func from_dict(data: Dictionary) -> void:
    _knowledge.from_dict(data.get(_knowledge.section_id(), { }))


## Aggregates migrate() for the knowledge store. Idempotent.
func migrate() -> void:
    _knowledge.migrate()

# ── Mastery ────────────────────────────────────────────────────────────────────


func add_category_points(category: CategoryData, rarity: ItemData.Rarity, action: KnowledgeAction) -> void:
    var base: int = _BASE_MASTERY[action]
    var rarity_mult: int = rarity + 1
    var gain: int = base * rarity_mult
    _knowledge.add_points(category.category_id, gain)


## Returns the mastery points recorded for [param category], or 0 if none.
func get_category_points(category: CategoryData) -> int:
    return _knowledge.category_points.get(category.category_id, 0)


## Returns the category IDs that currently have mastery points recorded.
func get_tracked_category_ids() -> Array:
    return _knowledge.category_points.keys()


## Removes the mastery-points entry for [param category_id]. Does not save.
## Used during migration to prune stale category IDs.
func erase_category_points(category_id: String) -> void:
    _knowledge.erase_points(category_id)


func get_category_rank(category: CategoryData) -> int:
    var points: int = _knowledge.category_points.get(category.category_id, 0)
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

# ── Attribute registry ─────────────────────────────────────────────────────────


func get_attribute_value(attribute_id: String) -> int:
    var attr: AttributeData = get_attribute_by_id(attribute_id)
    var default_value: int = attr.starting_value if attr != null else 1
    return _knowledge.attribute_levels.get(attribute_id, default_value)


func get_attribute_by_id(attribute_id: String) -> AttributeData:
    return _attribute_registry.get(attribute_id, null)


func get_all_attributes() -> Array[AttributeData]:
    var result: Array[AttributeData] = []
    for attr: AttributeData in _attribute_registry.values():
        result.append(attr)
    return result


func attribute_count() -> int:
    return _attribute_registry.size()


## Returns the cash cost to upgrade any attribute by one level.
func attribute_upgrade_cost() -> int:
    return _ATTRIBUTE_UPGRADE_COST


## Pure domain mutation: raises [param attr] one level in KnowledgeStore.
## Does NOT spend cash and does NOT save — the calling transaction
## (MetaManager.upgrade_attribute) handles both.
func raise_attribute_level(attr: AttributeData) -> void:
    var current := _knowledge.attribute_levels.get(attr.attribute_id, attr.starting_value)
    _knowledge.set_attribute_level(attr.attribute_id, current + 1)

# ── Perk registry ──────────────────────────────────────────────────────────────


func unlock_perk(perk: PerkData) -> void:
    if not _knowledge.add_perk(perk.perk_id):
        return
    SaveManager.save()


func has_perk(perk: PerkData) -> bool:
    return perk.perk_id in _knowledge.unlocked_perks


func has_perk_by_id(perk_id: String) -> bool:
    return perk_id in _knowledge.unlocked_perks


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

# ── EventBus handlers ──────────────────────────────────────────────────────────


func _on_sale_resolved(category: CategoryData, rarity: ItemData.Rarity) -> void:
    add_category_points(category, rarity, KnowledgeAction.SELL)


func _on_item_repaired(category: CategoryData, rarity: ItemData.Rarity) -> void:
    add_category_points(category, rarity, KnowledgeAction.REPAIR)


func _on_item_restored(category: CategoryData, rarity: ItemData.Rarity) -> void:
    add_category_points(category, rarity, KnowledgeAction.RESTORE)
