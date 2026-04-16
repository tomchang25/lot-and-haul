# special_order_slot_data.gd
# Designer-authored sub-resource describing one profile in a SpecialOrderData
# slot pool. A generated order picks pool entries uniformly at random and
# constructs each OrderSlot from the chosen entry.
class_name SpecialOrderSlotData
extends Resource

# Categories a slot rolled from this pool entry may target.
# A single category is picked uniformly from this array at generation time.
@export var categories: Array[CategoryData] = []

# Fixed rarity floor applied to every slot from this entry.
# -1 means no gate; otherwise matches an ItemData.Rarity value.
@export var rarity_floor: int = -1

# Fixed condition floor applied to every slot from this entry.
# 0.0 means no gate; otherwise the minimum condition in [0, 1].
@export var condition_floor: float = 0.0

# Inclusive range for the slot's required_count.
@export var count_min: int = 1
@export var count_max: int = 1
