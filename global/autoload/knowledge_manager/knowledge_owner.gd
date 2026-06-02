# knowledge_owner.gd
# Knowledge domain owner: category mastery, attribute levels, and unlocked perks.
# Owns the three persistent fields, their serialization, and no-save mutators.
# Held by KnowledgeManager; not a global singleton.
class_name KnowledgeOwner
extends RefCounted

## Per-category mastery points. Keys are category IDs (String), values are int.
var category_points: Dictionary = {}

## Per-attribute upgrade levels. Keys are attribute_id (String), values are int.
var attribute_levels: Dictionary = {}

## Perk IDs the player has unlocked.
var unlocked_perks: Array[String] = []

# ── Mutators (no save) ──────────────────────────────────────────────────────────

## Adds [param gain] mastery points to [param category_id]. Does not save.
func add_points(category_id: String, gain: int) -> void:
	if not category_points.has(category_id):
		category_points[category_id] = 0
	category_points[category_id] += gain


## Sets the stored level for [param attribute_id]. Does not save.
func set_attribute_level(attribute_id: String, level: int) -> void:
	attribute_levels[attribute_id] = level


## Appends [param perk_id] to unlocked_perks. Returns false if already present.
## Does not save.
func add_perk(perk_id: String) -> bool:
	if unlocked_perks.has(perk_id):
		return false
	unlocked_perks.append(perk_id)
	return true


## Removes [param category_id] from category_points. Does not save.
## Used during migration to prune stale category IDs.
func erase_points(category_id: String) -> void:
	category_points.erase(category_id)

# ── Save section ───────────────────────────────────────────────────────────────

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
