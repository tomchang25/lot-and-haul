# layer_unlock_action.gd
# Inline resource embedded in each IdentityLayer.
# Describes what is required to advance from the previous layer to this one.
# Null on the final layer — no further advancement possible.
class_name LayerUnlockAction
extends Resource

# Stamina cost to perform this action.
@export var stamina_cost: int = 0

# Skill identifier required before this action is available.
# Empty string means no skill prerequisite.
@export var required_skill: String = ""

# Minimum level in required_skill to perform this action.
# Ignored when required_skill is empty.
@export var required_level: int = 0

# Whether this action can be performed during auction lot preview.
# Simple visual inspection: true. Requires handling or deep research: false.
@export var allowed_at_auction: bool = false
