# skill_level_data.gd
# Sub-resource describing the requirements and cost to reach one skill level.
# Embedded inside SkillData.levels[].
class_name SkillLevelData
extends Resource

@export var cash_cost: int = 0

## Required super-category ranks. Key = super_category_id (String), value = min rank (int).
## Empty dict = no super-category gate. Multiple keys = ALL must be met.
@export var required_super_category_ranks: Dictionary = {}

## Required global mastery rank. 0 = no gate.
@export var required_mastery_rank: int = 0
