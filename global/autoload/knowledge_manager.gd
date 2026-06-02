# knowledge_manager.gd
# Knowledge progression: category mastery, attribute levels, and unlocked perks.
# Owns the persistent state for these domains and provides the "knowledge" save section.
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

# ── Persistent state ──────────────────────────────────────────────────────────

## Per-category mastery points. Keys are category IDs (String), values are int.
var category_points: Dictionary = {}

## Per-attribute upgrade levels. Keys are attribute_id (String), values are int.
var attribute_levels: Dictionary = {}

## Perk IDs the player has unlocked.
var unlocked_perks: Array[String] = []

# ── Registry (non-persistent) ─────────────────────────────────────────────────

var _perk_registry: Dictionary = {}       # perk_id → PerkData
var _attribute_registry: Dictionary = {}  # attribute_id → AttributeData


func _ready() -> void:
    _load_perk_registry()
    _load_attribute_registry()
    SaveManager.register_section(self)
    RegistryCoordinator.register(self)

# ── Save section provider ─────────────────────────────────────────────────────


## Section id for the knowledge save payload.
func section_id() -> String:
    return "knowledge"


## Serializes knowledge progression to a save payload.
func to_dict() -> Dictionary:
    return {
        "category_points": category_points,
        "attribute_levels": attribute_levels,
        "unlocked_perks": unlocked_perks,
    }


## Restores knowledge progression from a save payload.
##
## Handles legacy flat saves (keys read directly from the flat dict) and
## schema-2 sectioned saves (coordinator dispatches the knowledge sub-dict).
## Also migrates old skill_levels by discarding them and starting fresh.
func from_dict(data: Dictionary) -> void:
    if data.has("category_points") and data["category_points"] is Dictionary:
        category_points = data["category_points"]
    if data.has("unlocked_perks") and data["unlocked_perks"] is Array:
        unlocked_perks = []
        for s: Variant in data["unlocked_perks"]:
            if s is String:
                unlocked_perks.append(s)
    if data.has("attribute_levels") and data["attribute_levels"] is Dictionary:
        attribute_levels = {}
        for key: Variant in data["attribute_levels"]:
            if key is String and data["attribute_levels"][key] is float:
                attribute_levels[key] = int(data["attribute_levels"][key])
    elif data.has("skill_levels"):
        # Migration: discard old skill_levels, start fresh with defaults.
        attribute_levels = {}
    else:
        attribute_levels = {}

# ── Registry validation ────────────────────────────────────────────────────────


func validate() -> bool:
    var ok := true
    if perk_count() == 0:
        push_error("KnowledgeManager: perk registry is empty")
        ok = false
    if attribute_count() == 0:
        push_error("KnowledgeManager: attribute registry is empty")
        ok = false
    for perk_id: String in unlocked_perks:
        if get_perk_by_id(perk_id) == null:
            push_error(
                "KnowledgeManager: unlocked_perks '%s' not found" % perk_id,
            )
            ok = false
    return ok

# ── Mastery ────────────────────────────────────────────────────────────────────


func add_category_points(category: CategoryData, rarity: ItemData.Rarity, action: KnowledgeAction) -> void:
    var base: int = _BASE_MASTERY[action]
    var rarity_mult: int = rarity + 1
    var gain: int = base * rarity_mult
    var category_id: String = category.category_id
    if not category_points.has(category_id):
        category_points[category_id] = 0
    category_points[category_id] += gain


func get_category_rank(category: CategoryData) -> int:
    var points: int = category_points.get(category.category_id, 0)
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
    return attribute_levels.get(attribute_id, default_value)


func get_attribute_by_id(attribute_id: String) -> AttributeData:
    return _attribute_registry.get(attribute_id, null)


func get_all_attributes() -> Array[AttributeData]:
    var result: Array[AttributeData] = []
    for attr: AttributeData in _attribute_registry.values():
        result.append(attr)
    return result


func attribute_count() -> int:
    return _attribute_registry.size()


## Upgrades an attribute by one level. Deducts the upgrade cost from
## MetaManager.cash. Returns false if the attribute is unknown or cash is
## insufficient.
func upgrade_attribute(attribute_id: String) -> bool:
    var attr: AttributeData = get_attribute_by_id(attribute_id)
    if attr == null:
        return false
    if MetaManager.cash < _ATTRIBUTE_UPGRADE_COST:
        return false
    MetaManager.cash -= _ATTRIBUTE_UPGRADE_COST
    var current := attribute_levels.get(attribute_id, attr.starting_value)
    attribute_levels[attribute_id] = current + 1
    SaveManager.save()
    return true

# ── Perk registry ──────────────────────────────────────────────────────────────


func unlock_perk(perk: PerkData) -> void:
    if unlocked_perks.has(perk.perk_id):
        return
    unlocked_perks.append(perk.perk_id)
    SaveManager.save()


func has_perk(perk: PerkData) -> bool:
    return perk.perk_id in unlocked_perks


func has_perk_by_id(perk_id: String) -> bool:
    return perk_id in unlocked_perks


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
