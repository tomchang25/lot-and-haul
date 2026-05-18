# clue_data.gd
# Inline resource embedded in each IdentityLayer.
# Describes one revealable clue for an item identity layer.
class_name ClueData
extends Resource

# Unique identifier. Must be unique across all clues in the project.
@export var clue_id: String = ""

# Text shown when this clue has been revealed.
@export var known_text: String = ""

# Optional hint shown before the clue is revealed.
# If empty, the UI auto-generates from prerequisites.
@export var unknown_hint_text: String = ""

# Extra AP added to the ADVANCE action cost when this clue is not yet revealed.
@export var ap_cost_penalty: int = 0

# Prerequisites - all optional. Structure mirrors LayerUnlockAction.
@export var required_skill: SkillData = null
@export var required_level: int = 0
@export var required_category_rank: int = 0
@export var required_perk: PerkData = null
