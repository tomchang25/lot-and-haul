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

# Maximum level this skill can reach.
@export var max_level: int = 5
