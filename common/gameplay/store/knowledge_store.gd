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

# ── Save section ───────────────────────────────────────────────────────────────


## Section id for the knowledge save payload.
func section_id() -> String:
    return "knowledge"


## Serializes knowledge progression to a save payload.
func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "category_points": _category_points,
        "attribute_levels": _attribute_levels,
        "unlocked_perks": _unlocked_perks,
    }


## Restores knowledge progression from a save payload.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
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
            if key is String:
                _attribute_levels[key] = int(data["attribute_levels"][key])
