# perk_data.gd
# Designer-authored resource representing one unlockable perk.
# Perks are sourced from attribute thresholds — when an attribute reaches a
# specific value, it unlocks one or more perks.
# Place .tres files under data/tres/perks/
class_name PerkData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
# This is the string stored in SaveManager.unlocked_perks.
@export var perk_id: String = ""

@export var display_name: String = ""

@export var description: String = ""

# Attribute that gates this perk.
@export var required_attribute: String = ""

# Minimum attribute value required to unlock this perk.
@export var required_attribute_value: int = 0
