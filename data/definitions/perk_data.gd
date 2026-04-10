# perk_data.gd
# Designer-authored resource representing one unlockable perk.
# Perks have no fixed unlock path — they are granted by calling
# KnowledgeManager.unlock_perk(perk_id) from any system (cash purchase,
# quest reward, etc.).
# Place .tres files under data/tres/perks/
class_name PerkData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
# This is the string stored in SaveManager.unlocked_perks.
@export var perk_id: String = ""

@export var display_name: String = ""

@export var description: String = ""
