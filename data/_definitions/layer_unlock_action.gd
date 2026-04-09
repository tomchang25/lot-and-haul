# layer_unlock_action.gd
# Inline resource embedded in each IdentityLayer.
# Describes what is required to advance from this layer to the next.
# Null on the final layer — no further advancement possible.
class_name LayerUnlockAction
extends Resource

# Where this action can be performed.
#   AUTO    — triggered automatically on arrival at home; no player input required.
#             Used exclusively for layer 0 → 1 (veiled → unveiled).
#   HOME    — requires the home workshop. Handling, research, tools, and skilled work.
enum ActionContext {
    AUTO,
    HOME,
}

@export var context: ActionContext = ActionContext.HOME

# Time take to perform this action.
# Ignored when context is AUTO.
@export var unlock_days: int = 0

# Skill required before this action is available.
# Null means no skill prerequisite.
@export var required_skill: SkillData = null

# Minimum level in required_skill to perform this action.
# Ignored when required_skill is null.
@export var required_level: int = 0

@export var required_condition: float = 0.0

# Minimum category rank for the item's category. 0 = no gate.
@export var required_category_rank: int = 0

# Perk required before this action is available. "" = no gate.
@export var required_perk_id: String = ""
