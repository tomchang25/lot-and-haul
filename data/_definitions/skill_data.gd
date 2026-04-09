# skill_data.gd
# Designer-authored resource representing a learnable player skill.
# Referenced by LayerUnlockAction to gate identity layer advancement.
# Place .tres files under data/skills/
class_name SkillData
extends Resource

# Internal identifier. Used in code and DB. Never displayed to the player.
@export var skill_id: String = ""

# Name shown in UI (skill list, action tooltip, etc.).
@export var display_name: String = ""

# DEPRECATED: array size of levels is the new authoritative max
@export var max_level: int = 5

# Index 0 = requirements to reach level 1.
# Array size determines max level (typically 5).
@export var levels: Array[SkillLevelData] = []
