# special_order_slot_pool_entry.gd
# Sub-resource describing one slot profile within a SpecialOrderData pool.
# Each entry defines the categories, rarity/condition floors, and count range
# a generated OrderSlot may use. SpecialOrder.create() picks one entry per slot
# uniformly at random from SpecialOrderData.slot_pool.
class_name SpecialOrderSlotPoolEntry
extends Resource

# Categories a slot built from this entry may target. The slot picks one
# category uniformly from this list.
@export var categories: Array[CategoryData] = []

# Minimum rarity (ItemData.Rarity value) for items accepted by the slot.
# -1 = no gate.
@export var rarity_floor: int = -1

# Minimum condition for items accepted by the slot. 0.0 = no gate.
@export var condition_floor: float = 0.0

# Required-count range rolled on slot creation via randi_range().
@export var count_min: int = 1
@export var count_max: int = 1
