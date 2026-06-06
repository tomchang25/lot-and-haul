# knowledge_store.gd
# Knowledge runtime store: category mastery, attribute levels, and unlocked
# perks. Serializable state slice held by KnowledgeManager. Owns the three
# persistent fields, their serialization, and no-save mutators.
class_name KnowledgeStore
extends StoreBase

var _category_points: Dictionary = { }
var _attribute_levels: Dictionary = { }
var _unlocked_perks: Array[String] = []

## Per-category mastery points. Keys are category IDs (String), values are int.
var category_points: Dictionary:
    get:
        return _category_points

## Per-attribute upgrade levels. Keys are attribute_id (String), values are int.
var attribute_levels: Dictionary:
    get:
        return _attribute_levels

## Perk IDs the player has unlocked.
var unlocked_perks: Array[String]:
    get:
        return _unlocked_perks

# ── Mutators (no save) ──────────────────────────────────────────────────────────


## Adds [param gain] mastery points to [param category_id]. Does not save.
func add_points(category_id: String, gain: int) -> void:
    if not _category_points.has(category_id):
        _category_points[category_id] = 0
    _category_points[category_id] += gain


## Sets the stored level for [param attribute_id]. Does not save.
func set_attribute_level(attribute_id: String, level: int) -> void:
    _attribute_levels[attribute_id] = level


## Appends [param perk_id] to unlocked_perks. Returns false if already present.
## Does not save.
func add_perk(perk_id: String) -> bool:
    if _unlocked_perks.has(perk_id):
        return false
    _unlocked_perks.append(perk_id)
    return true


## Removes [param category_id] from category_points. Does not save.
## Used during migration to prune stale category IDs.
func erase_points(category_id: String) -> void:
    _category_points.erase(category_id)


## Idempotent migration: prunes category_points keys that no longer exist in
## CategoryRegistry. Mirrors the logic previously in CategoryRegistry.migrate().
## CategoryRegistry is loaded before SaveManager/KnowledgeManager, so it is
## available here.
func migrate() -> void:
    for key: String in _category_points.keys():
        if CategoryRegistry.get_category_by_id(key) == null:
            push_warning(
                "KnowledgeStore.migrate: dropping unknown category_points key '%s'" % key,
            )
            _category_points.erase(key)

# ── Save section ───────────────────────────────────────────────────────────────


## Section id for the knowledge save payload.
func section_id() -> String:
    return "knowledge"


## Serializes knowledge progression to a save payload.
func to_dict() -> Dictionary:
    return {
        "category_points": _category_points,
        "attribute_levels": _attribute_levels,
        "unlocked_perks": _unlocked_perks,
    }


## Restores knowledge progression from a save payload.
##
## Handles legacy flat saves (keys read directly from the flat dict) and
## schema-2 sectioned saves (coordinator dispatches the knowledge sub-dict).
## Also migrates old skill_levels by discarding them and starting fresh.
func from_dict(data: Dictionary) -> void:
    if data.has("category_points") and data["category_points"] is Dictionary:
        _category_points = data["category_points"]
    if data.has("unlocked_perks") and data["unlocked_perks"] is Array:
        _unlocked_perks = []
        for s: Variant in data["unlocked_perks"]:
            if s is String:
                _unlocked_perks.append(s)
    if data.has("attribute_levels") and data["attribute_levels"] is Dictionary:
        _attribute_levels = { }
        for key: Variant in data["attribute_levels"]:
            if key is String and data["attribute_levels"][key] is float:
                _attribute_levels[key] = int(data["attribute_levels"][key])
    elif data.has("skill_levels"):
        # Migration: discard old skill_levels, start fresh with defaults.
        _attribute_levels = { }
    else:
        _attribute_levels = { }
