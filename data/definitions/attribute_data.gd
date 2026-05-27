# attribute_data.gd
# Designer-authored resource representing a SPECIAL-style player attribute.
# Attributes provide bonuses to clue discovery dice rolls.
# Place .tres files under data/tres/attributes/
class_name AttributeData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
@export var attribute_id: String = ""

# Human-readable label shown to the player.
@export var display_name: String = ""

# Starting value when a new game begins.
@export var starting_value: int = 1
